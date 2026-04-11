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
    final lines = resultText.split('\n');

    String? xLine, yLine, zLine, vxLine, vyLine, vzLine;
    for (final line in lines) {
      if (line.contains(' X =')) xLine = line;
      if (line.contains(' Y =')) yLine = line;
      if (line.contains(' Z =')) zLine = line;
      if (line.contains('VX=')) vxLine = line;
      if (line.contains('VY=')) vyLine = line;
      if (line.contains('VZ=')) vzLine = line;
    }

    final BigDec kmToM = BigDec.fromString("1000")..setDecimalPrecision(200);

    return Body(
      name: name,
      gm: _parseGMFromHeader(resultText),
      position: Vector3(
        x: parseHorizonsNumber(xLine!.split('=')[1]).multiply(kmToM),
        y: parseHorizonsNumber(yLine!.split('=')[1]).multiply(kmToM),
        z: parseHorizonsNumber(zLine!.split('=')[1]).multiply(kmToM),
      ),
      velocity: Vector3(
        x: parseHorizonsNumber(vxLine!.split('=')[1]).multiply(kmToM),
        y: parseHorizonsNumber(vyLine!.split('=')[1]).multiply(kmToM),
        z: parseHorizonsNumber(vzLine!.split('=')[1]).multiply(kmToM),
      ),
    );
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

  test("Full Solar System Warp Simulation vs Horizons", () async {
    const String startDate = "2023-01-01";
    const String endDate   = "2023-01-16"; // 15 days

    final List<Map<String, String>> bodyConfigs = [
      {'id': '10',  'name': 'Sun'},
      {'id': '199', 'name': 'Mercury'},
      {'id': '299', 'name': 'Venus'},
      {'id': '399', 'name': 'Earth'},
      {'id': '499', 'name': 'Mars'},
      {'id': '599', 'name': 'Jupiter'},
      {'id': '699', 'name': 'Saturn'},
      {'id': '799', 'name': 'Uranus'},
      {'id': '899', 'name': 'Neptune'},
    ];

    List<Body> nasaInitial = [];
    Map<String, Body> truthMap = {};

    print("Fetching initial and truth data from NASA Horizons...");
    for (var config in bodyConfigs) {
      nasaInitial.add(await nasa.fetchBody(config['id']!, config['name']!, startDate));
      truthMap[config['name']!] = await nasa.fetchBody(config['id']!, config['name']!, endDate);
    }

    print("-------------Antikythera Simulation--------------");
    DateTime simStart = DateTime.now();
    const int simSteps = 10_000;
    print("Sim Start: ${simStart.toString()}");
    print("Sim Steps: $simSteps");
    Antikythera sim = Antikythera(bodies: nasaInitial);
    BigDec fifteenDaysInSeconds = BigDec.fromString("1296000")..setDecimalPrecision(200);
    // Simulate for 1 Solar Year
    sim.simulate(
      totalTime: fifteenDaysInSeconds,
      steps: BigInt.from(simSteps), // Increased steps for precision across all planets
    );
    DateTime simEnd = DateTime.now();
    print("Sim End: ${simEnd.toString()}");
    Duration timeElapsed = simEnd.difference(simStart);
    print("Time Elapsed: ${timeElapsed.toString()}");
    sim.recenterToBarycenter();

    print("\n--- ERROR ANALYSIS LOG ---");
    final BigDec hundred = BigDec.fromString("100")..setDecimalPrecision(200);

    for (var config in bodyConfigs) {
      String name = config['name']!;
      if (name == 'Sun') continue; // Error percentage for the center isn't meaningful

      Body truth = truthMap[name]!;
      Body simBody = sim.getBodyByName(name)!;

      // Distance between predicted and actual position
      BigDec absoluteError = simBody.position.subtract(truth.position).magnitude();
      
      // Actual orbital distance from origin (Sun)
      BigDec actualDistance = truth.position.magnitude();
      
      // Percentage Error = (Absolute Error / Actual Distance) * 100
      BigDec percentError = absoluteError.divide(actualDistance).multiply(hundred);

      print("$name:");
      print("  - Absolute Error: ${absoluteError.toStringAsFixed(2)} meters");
      print("  - Percent Error:  ${percentError.toStringAsFixed(8)}%");
    }
  });
}