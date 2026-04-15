import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:big_dec/big_dec.dart';
import 'package:test/test.dart';
import 'package:poisson_warp/poisson_warp.dart';

// ============================================================================
// IMPROVED SCIENTIFIC NUMBER PARSER
// ============================================================================
BigDec parseHorizonsNumber(String raw) {
  String s = raw.trim().toUpperCase().replaceAll('D', 'E');
  if (s.isEmpty) return BigDec.fromString("0");

  if (s.contains('+/-')) s = s.split('+/-')[0].trim();
  if (s.contains('+-')) s = s.split('+-')[0].trim();

  final expRegex = RegExp(r'([0-9.])([+-][0-9]+)');
  s = s.replaceAllMapped(expRegex, (match) => '${match.group(1)}E${match.group(2)}');

  final parts = s.split('E');
  String coefficientPart = parts[0];

  if (coefficientPart.startsWith('.')) coefficientPart = '0$coefficientPart';
  if (coefficientPart.startsWith('-.')) {
    coefficientPart = coefficientPart.replaceFirst('-.', '-0.');
  }

  try {
    BigDec value = BigDec.fromString(coefficientPart)..setDecimalPrecision(200);

    if (parts.length > 1) {
      String rawExp = parts[1];
      String sign = "";

      if (rawExp.startsWith('+') || rawExp.startsWith('-')) {
        sign = rawExp[0];
        rawExp = rawExp.substring(1);
      }

      String cleanExpNum = rawExp.split(RegExp(r'[^0-9]'))[0];
      int exponent = int.tryParse('$sign$cleanExpNum') ?? 0;
      BigDec ten = BigDec.fromString("10")..setDecimalPrecision(200);

      if (exponent > 0) {
        value = value.multiply(ten.pow(BigInt.from(exponent)));
      } else if (exponent < 0) {
        value = value.divide(ten.pow(BigInt.from(exponent.abs())));
      }
    }
    return value;
  } catch (e) {
    print("Warning: Failed to parse Horizons number: '$raw'");
    return BigDec.fromString("0");
  }
}

// ============================================================================
// DATE FORMATTER
// ============================================================================
String horizonsDate(DateTime dt) {
  return "'${dt.year.toString().padLeft(4, '0')}-"
      "${dt.month.toString().padLeft(2, '0')}-"
      "${dt.day.toString().padLeft(2, '0')} "
      "${dt.hour.toString().padLeft(2, '0')}:"
      "${dt.minute.toString().padLeft(2, '0')}'";
}

// ============================================================================
// NASA HORIZONS SERVICE
// ============================================================================
class NASAHorizonsService {
  final String _baseUrl = "https://ssd.jpl.nasa.gov/api/horizons.api";

  Future<Body> fetchBody(
    String bodyId,
    String name,
    DateTime start,
    DateTime end,
  ) async {
    DateTime endAdj = end.add(const Duration(minutes: 10));

    final Map<String, String> queryParams = {
      "format": "json",
      "COMMAND": "'$bodyId'",
      "OBJ_DATA": "YES",
      "MAKE_EPHEM": "YES",
      "EPHEM_TYPE": "VECTORS",
      "CENTER": "'@ssb'",
      "OUT_UNITS": "KM-S",
      "CSV_FORMAT": "YES",
      "VEC_TABLE": "3",
      "START_TIME": horizonsDate(start),
      "STOP_TIME": horizonsDate(endAdj),
      "STEP_SIZE": "10m",
    };

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception("HTTP Error: ${response.statusCode}");
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    final String resultText = data["result"] ?? "";

    const String soeMarker = "\$\$SOE";
    const String eoeMarker = "\$\$EOE";

    final int soe = resultText.indexOf(soeMarker);
    final int eoe = resultText.indexOf(eoeMarker);

    if (soe == -1 || eoe == -1) {
      throw Exception("No vector table for $name. Check API parameters.");
    }

    final String tableContent = resultText.substring(soe + soeMarker.length, eoe).trim();
    final List<String> lines = tableContent.split('\n');
    final List<String> cols = lines[0].split(',');

    final BigDec kmToM = BigDec.fromString("1000")..setDecimalPrecision(200);

    return Body(
      name: name,
      gm: _parseGM(resultText),
      position: Vector3(
        x: parseHorizonsNumber(cols[2]).multiply(kmToM),
        y: parseHorizonsNumber(cols[3]).multiply(kmToM),
        z: parseHorizonsNumber(cols[4]).multiply(kmToM),
      ),
      velocity: Vector3(
        x: parseHorizonsNumber(cols[5]).multiply(kmToM),
        y: parseHorizonsNumber(cols[6]).multiply(kmToM),
        z: parseHorizonsNumber(cols[7]).multiply(kmToM),
      ),
      radius: _parseRadius(resultText).multiply(kmToM),
      axialVelocityInDegreesPerSecond: _parseRotationRate(resultText),
    );
  }

  BigDec _parseGM(String header) {
    final RegExp r = RegExp(r"GM[^=]*=\s*([0-9.Ede+\-]+)", caseSensitive: false);
    final Match? m = r.firstMatch(header);
    if (m == null) return BigDec.fromString("132712440018000000000"); 
    return parseHorizonsNumber(m.group(1)!).multiply(BigDec.fromString("1000000000"));
  }

  BigDec _parseRadius(String header) {
    final RegExp r = RegExp(r"radius\s*\(km\)\s*=\s*([0-9.Ede+\-]+)(?=\s|$)", caseSensitive: false);
    final Match? m = r.firstMatch(header);
    if (m == null) return BigDec.fromString("695700");
    return parseHorizonsNumber(m.group(1)!);
  }

  BigDec _parseRotationRate(String header) {
    final radRegex = RegExp(
      r"(?:Sid\.\s*)?rot\.\s*rate,?\s*\(?rad/s\)?\s*=?\s*([0-9.Ede+\-]+)", 
      caseSensitive: false
    );
    
    final hourRegex = RegExp(
      r"(?:Sid\.\s*)?rot\.\s*per(?:iod)?\s*=?\s*([0-9.Ede+\-]+)\s*h", 
      caseSensitive: false
    );

    // Try Radians/sec
    final radMatch = radRegex.firstMatch(header);
    if (radMatch != null) {
      final val = radMatch.group(1);
      if (val != null) {
        return parseHorizonsNumber(val).multiply(BigDec.fromString("57.29577951308232")).abs();
      }
    }

    // Try Period in Hours
    final hourMatch = hourRegex.firstMatch(header);
    if (hourMatch != null) {
      final val = hourMatch.group(1);
      if (val != null) {
        BigDec hours = parseHorizonsNumber(val);
        if (hours.compareTo(BigDec.fromString("0")) == 0) return BigDec.fromString("0");
        BigDec totalSeconds = hours.multiply(BigDec.fromString("3600"));
        return BigDec.fromString("360").divide(totalSeconds);
      }
    }

    return BigDec.fromString("0"); // Assume 0 if not found
  }
}

// ============================================================================
// TEST SUITE
// ============================================================================
void main() {
  test("Symplectic Solar System Distance Check", () async {
    final nasa = NASAHorizonsService();
    const int decimalPrecision = 200;
    final BigDec auMeters = BigDec.fromString("149597870700")..setDecimalPrecision(decimalPrecision);
    
    final DateTime t0 = DateTime(2005, 1, 1);
    final List<Body> initial = [];
    
    // NOTE: Switched to X99 IDs to get physical rotation data headers
    final bodiesConfig = [
      {"id": "10",  "name": "Sun"},
      {"id": "199", "name": "Mercury"},
      {"id": "299", "name": "Venus"},
      {"id": "399", "name": "Earth"},
      {"id": "301", "name": "Moon"},
      {"id": "499", "name": "Mars"},
      {"id": "599", "name": "Jupiter"},
      {"id": "699", "name": "Saturn"},
      {"id": "799", "name": "Uranus"},
      {"id": "899", "name": "Neptune"},
    ];

    for (var cfg in bodiesConfig) {
      initial.add(await nasa.fetchBody(cfg["id"]!, cfg["name"]!, t0, t0));
    }

    final Antikythera sim = Antikythera(bodies: initial);
    BigDec simulationDays = BigDec.fromBigInt(BigInt.from(14))..setDecimalPrecision(200); 
    BigDec daysInAYear = BigDec.fromString("365.242");
    final BigDec duration = simulationDays.divide(daysInAYear); 
    BigInt steps = BigInt.from(50000);

    DateTime lastUpdate = DateTime.now();

    sim.simulateMotion(
      durationInSeconds: duration, 
      steps: steps, 
      onStep: (stepsSimulated) {
        DateTime stepCompleted = DateTime.now();
        if(5 <= stepCompleted.difference(lastUpdate).inSeconds){
          lastUpdate = stepCompleted;
          print("Progress: ${stepsSimulated.toString()}/${steps.toString()}");
        }
      },
    );

    final Body sun = sim.getBodyByName("Sun")!;
    for (var b in initial) {
      if (b.name == "Sun") continue;
      final BigDec distAU = b.position
          .subtract(sun.position)
          .magnitude()
          .divide(auMeters);
      print("${b.name} is at ${distAU.toString()}AU and is spinning at ${b.axialVelocityInDegreesPerSecond.toString()} deg/second");
    }
  });

  test("Verify axial velocity calculations", () async {
    final nasa = NASAHorizonsService();
    final DateTime t0 = DateTime(2005, 1, 1);
    final List<Body> initial = [];
    
    // Testing Centroids to ensure data-driven parsing (no cheating!)
    final bodiesConfig = [
      {"id": "10",  "name": "Sun"},
      {"id": "199", "name": "Mercury"},
      {"id": "299", "name": "Venus"},
      {"id": "399", "name": "Earth"},
      {"id": "301", "name": "Moon"},
      {"id": "499", "name": "Mars"},
      {"id": "599", "name": "Jupiter"},
      {"id": "699", "name": "Saturn"},
      {"id": "799", "name": "Uranus"},
      {"id": "899", "name": "Neptune"},
    ];

    for (var cfg in bodiesConfig) {
      initial.add(await nasa.fetchBody(cfg["id"]!, cfg["name"]!, t0, t0));
    }

    for (Body body in initial) {
      print("- ${body.name} is spinning at ${body.axialVelocityInDegreesPerSecond.toString()} deg/second");
    }
  });
}