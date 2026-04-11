import 'package:test/test.dart';
import 'dart:convert';
import 'package:big_dec/big_dec.dart';
import 'package:http/http.dart' as http;
import 'package:poisson_warp/poisson_warp.dart';

// ============================================================================
// ROBUST HORIZONS NUMBER PARSER
// ============================================================================
BigDec parseHorizonsNumber(String raw) {
  String s = raw.trim().toUpperCase();
  s = s.replaceAll(RegExp(r'[^0-9+\-\.ED]'), '');
  if (s.isEmpty) throw FormatException("Non-numeric Horizons field: '$raw'");
  s = s.replaceAll('D', 'E');
  if (s.startsWith('.')) s = '0$s';
  if (s.startsWith('-.')) s = s.replaceFirst('-.', '-0.');

  if (!s.contains('E')) {
    return BigDec.fromString(s)..setDecimalPrecision(200);
  }

  final parts = s.split('E');
  final coeff = BigDec.fromString(parts[0])..setDecimalPrecision(200);
  final int exp = int.parse(parts[1]);
  final ten = BigDec.fromString("10")..setDecimalPrecision(200);

  if (exp >= 0) {
    return coeff.multiply(ten.pow(BigInt.from(exp)));
  } else {
    return coeff.divide(ten.pow(BigInt.from(exp.abs())));
  }
}

class NASAHorizonsService {
  final String _baseUrl = "https://ssd.jpl.nasa.gov/api/horizons.api";

  Future<Body> fetchBody(String bodyId, String name, String dateTime) async {
    final DateTime dt = DateTime.parse(dateTime);
    final DateTime dt2 = dt.add(const Duration(days: 1));

    final queryParams = {
      'format': 'json',
      'COMMAND': "'$bodyId'",
      'EPHEM_TYPE': 'VECTORS',
      'CENTER': "'@0'", 
      'MAKE_EPHEM': 'YES',
      'OUT_UNITS': 'KM-S',
      'CSV_FORMAT': 'NO', 
      'VEC_TABLE': '2',
      'START_TIME': "'$dateTime'",
      'STOP_TIME': "'${dt2.toIso8601String().split('T').first}'",
      'STEP_SIZE': "'1 d'",
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
    final response = await http.get(uri);
    final Map<String, dynamic> data = jsonDecode(response.body);
    final String resultText = data['result'];

    final int soe = resultText.indexOf(r'$$SOE');
    final int eoe = resultText.indexOf(r'$$EOE');
    if (soe == -1 || eoe == -1) throw StateError("Vector data markers not found for $name");
    
    final String vectorBlock = resultText.substring(soe, eoe);
    final BigDec kmToM = BigDec.fromString("1000")..setDecimalPrecision(200);

    return Body(
      name: name,
      gm: _parseGMFromHeader(resultText),
      position: Vector3(
        x: parseHorizonsNumber(_extractValue(vectorBlock, 'X')).multiply(kmToM),
        y: parseHorizonsNumber(_extractValue(vectorBlock, 'Y')).multiply(kmToM),
        z: parseHorizonsNumber(_extractValue(vectorBlock, 'Z')).multiply(kmToM),
      ),
      velocity: Vector3(
        x: parseHorizonsNumber(_extractValue(vectorBlock, 'VX')).multiply(kmToM),
        y: parseHorizonsNumber(_extractValue(vectorBlock, 'VY')).multiply(kmToM),
        z: parseHorizonsNumber(_extractValue(vectorBlock, 'VZ')).multiply(kmToM),
      ),
    );
  }

  String _extractValue(String text, String label) {
    final regex = RegExp('$label\\s*=\\s*([0-9.Ede+\\-]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match == null) throw StateError("Label $label not found in vector data block");
    return match.group(1)!.trim();
  }

  BigDec _parseGMFromHeader(String header) {
    final gmMatch = RegExp(r'GM[^=]*=\s*([0-9.Ede+\-]+)', caseSensitive: false).firstMatch(header);
    if (gmMatch == null) throw StateError("GM missing in NASA header");
    
    BigDec gmKm3 = parseHorizonsNumber(gmMatch.group(1)!);
    return gmKm3.multiply(BigDec.fromString("1000000000")..setDecimalPrecision(200));
  }
}

void main() {
  final nasa = NASAHorizonsService();

  test("15-Day Solar System Alignment Validation", () async {
    const String startDate = "2023-01-01";
    const String endDate   = "2023-01-16"; 
    final int dp = 200;

    final List<Map<String, String>> bodyConfigs = [
      {'id': '10',  'name': 'Sun'},
      {'id': '199', 'name': 'Mercury'},
      {'id': '299', 'name': 'Venus'},
      {'id': '399', 'name': 'Earth'},
      {'id': '499', 'name': 'Mars'},
    ];

    List<Body> nasaInitial = [];
    Map<String, Body> truthMap = {};

    print("Fetching NASA Horizons data...");
    for (var config in bodyConfigs) {
      Body initial = await nasa.fetchBody(config['id']!, config['name']!, startDate);
      nasaInitial.add(initial);
      truthMap[config['name']!] = await nasa.fetchBody(config['id']!, config['name']!, endDate);
    }

    print("Running Antikythera physics simulation...");
    Antikythera sim = Antikythera(bodies: nasaInitial);
    BigDec fifteenDays = BigDec.fromString("1296000")..setDecimalPrecision(dp);
    
    // Step 1: Execute simulation in the Equatorial Frame (J2000)
    sim.simulateEquatorialFrame(durationSeconds: fifteenDays, decimalPlaces: dp);
    
    // Step 2: Recenter to the Solar System Barycenter
    sim.recenterBarycenter(decimalPlaces: dp);

    print("\n--- ERROR ANALYSIS LOG ---");

    for (var config in bodyConfigs) {
      String name = config['name']!;
      Body truth = truthMap[name]!;
      Body? simBody = sim.getBodyByName(name);

      if (simBody == null) {
        print("$name: Error - Not found in simulation results");
        continue;
      }

      Vector3 absoluteError = simBody.position.subtract(truth.position, decimalPlaces: dp);
      BigDec errorMagnitude = absoluteError.magnitude(decimalPlaces: dp);

      print("$name:");
      print("Absolute error: ${errorMagnitude.toString()} meters");
    }

    print("\n--- HELIOCENTRIC DISTANCES (AU) ---");

    final au = BigDec.fromString("149597870700")..setDecimalPrecision(dp);
    Body? sun = sim.getBodyByName("Sun");

    if (sun != null) {
      for (var config in bodyConfigs) {
        String name = config['name']!;
        if (name == "Sun") continue;

        Body? body = sim.getBodyByName(name);
        if (body != null) {
          // Calculate relative vector from Sun to Body
          Vector3 relativePos = body.position.subtract(sun.position, decimalPlaces: dp);
          
          // Calculate magnitude in meters
          BigDec distMeters = relativePos.magnitude(decimalPlaces: dp);
          
          // Convert meters to AU
          BigDec distAU = distMeters.divide(au);

          print("$name: ${distAU.toString()} AU");
        }
      }
    }
  });
  test("182-Day (Half Year) Solar System Alignment Validation - 1998", () async {
    const String startDate = "1998-02-20";
    const String endDate   = "1998-08-21"; // Exactly 182 days later
    final int dp = 200;

    final List<Map<String, String>> bodyConfigs = [
      {'id': '10',  'name': 'Sun'},
      {'id': '199', 'name': 'Mercury'},
      {'id': '299', 'name': 'Venus'},
      {'id': '399', 'name': 'Earth'},
      {'id': '499', 'name': 'Mars'},
    ];

    List<Body> nasaInitial = [];
    Map<String, Body> truthMap = {};

    print("Fetching NASA Horizons data for February 1998...");
    for (var config in bodyConfigs) {
      Body initial = await nasa.fetchBody(config['id']!, config['name']!, startDate);
      nasaInitial.add(initial);
      truthMap[config['name']!] = await nasa.fetchBody(config['id']!, config['name']!, endDate);
    }

    print("Running Antikythera physics simulation for 182 days...");
    Antikythera sim = Antikythera(bodies: nasaInitial);
    
    // 182 days in seconds = 182 * 24 * 60 * 60
    BigDec halfYearSeconds = BigDec.fromString("15724800")..setDecimalPrecision(dp);
    
    // Execute simulation and rotate to J2000 frame
    sim.simulateEquatorialFrame(durationSeconds: halfYearSeconds, decimalPlaces: dp);
    sim.recenterBarycenter(decimalPlaces: dp);

    print("\n--- ERROR ANALYSIS LOG (182 DAYS) ---");

    for (var config in bodyConfigs) {
      String name = config['name']!;
      Body truth = truthMap[name]!;
      Body? simBody = sim.getBodyByName(name);

      if (simBody == null) {
        print("$name: Error - Not found in simulation results");
        continue;
      }

      Vector3 absoluteError = simBody.position.subtract(truth.position, decimalPlaces: dp);
      BigDec errorMagnitude = absoluteError.magnitude(decimalPlaces: dp);

      print("$name:");
      print("Absolute error: ${errorMagnitude.toString()} meters");
    }

    print("\n--- HELIOCENTRIC DISTANCES (AU) ---");

    final au = BigDec.fromString("149597870700")..setDecimalPrecision(dp);
    Body? sun = sim.getBodyByName("Sun");

    if (sun != null) {
      for (var config in bodyConfigs) {
        String name = config['name']!;
        if (name == "Sun") continue;

        Body? body = sim.getBodyByName(name);
        if (body != null) {
          Vector3 relativePos = body.position.subtract(sun.position, decimalPlaces: dp);
          BigDec distMeters = relativePos.magnitude(decimalPlaces: dp);
          BigDec distAU = distMeters.divide(au);

          print("$name: ${distAU.toString()} AU");
        }
      }
    }
  });
}