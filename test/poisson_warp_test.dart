import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:big_dec/big_dec.dart';
import 'package:test/test.dart';
import 'package:poisson_warp/poisson_warp.dart';

// ============================================================================
// IMPROVED SCIENTIFIC NUMBER PARSER
// ============================================================================
BigDec parseHorizonsNumber(String raw) {
  // Clean string and normalize Fortran 'D' to standard 'E'
  String s = raw.trim().toUpperCase().replaceAll('D', 'E');
  if (s.isEmpty) return BigDec.fromString("0");

  // Split by scientific notation marker
  final parts = s.split('E');
  String coefficientPart = parts[0];

  // Fix common shorthand: ".5" -> "0.5" or "-.5" -> "-0.5"
  if (coefficientPart.startsWith('.')) coefficientPart = '0$coefficientPart';
  if (coefficientPart.startsWith('-.')) {
    coefficientPart = coefficientPart.replaceFirst('-.', '-0.');
  }

  // Create the coefficient as a high-precision BigDec
  BigDec value = BigDec.fromString(coefficientPart)..setDecimalPrecision(200);

  // Handle exponent (e.g., E+06 or E-11)
  if (parts.length > 1) {
    int exponent = int.parse(parts[1]);
    BigDec ten = BigDec.fromString("10")..setDecimalPrecision(200);

    if (exponent > 0) {
      // Multiply by 10^exp
      value = value.multiply(ten.pow(BigInt.from(exponent)));
    } else if (exponent < 0) {
      // Divide by 10^|exp|
      value = value.divide(ten.pow(BigInt.from(exponent.abs())));
    }
  }

  return value;
}

// ============================================================================
// DATE FORMATTER
// ============================================================================
String horizonsDate(DateTime dt) {
  // Literal single quotes are REQUIRED by the NASA back-end for space-separated dates
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
    // Horizons needs a duration (at least 1 minute) to generate an ephemeris table
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

    // CSV line format: JDTDB, Calendar, X, Y, Z, VX, VY, VZ
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
    );
  }

  BigDec _parseGM(String header) {
    // NASA often writes "GM= 1.327E+11"
    final RegExp r = RegExp(r"GM[^=]*=\s*([0-9.Ede+\-]+)", caseSensitive: false);
    final Match? m = r.firstMatch(header);
    if (m == null) {
      return BigDec.fromString("132712440018000000000")..setDecimalPrecision(200);
    }
    final BigDec gmKm3 = parseHorizonsNumber(m.group(1)!);
    return gmKm3.multiply(BigDec.fromString("1000000000")..setDecimalPrecision(200));
  }
}

// ============================================================================
// TEST SUITE
// ============================================================================
void main() {
  test("Symplectic Solar System Distance Check", () async {
    final nasa = NASAHorizonsService();
    const int dp = 200;
    final BigDec auMeters = BigDec.fromString("149597870700")..setDecimalPrecision(dp);
    
    // Fetch start state (15-day run)
    final DateTime t0 = DateTime(2005, 1, 1);
    final List<Body> initial = [];
    final bodiesConfig = [
      {"id": "10",  "name": "Sun",     "gm": "132712440041.93938"},
      {"id": "199", "name": "Mercury", "gm": "22031.78"},
      {"id": "299", "name": "Venus",   "gm": "324858.59"},
      {"id": "399", "name": "Earth",   "gm": "398600.435"},
      {"id": "301", "name": "Moon",    "gm": "4902.800"},
      {"id": "4",   "name": "Mars",    "gm": "42828.375"},
      {"id": "5",   "name": "Jupiter", "gm": "126712762.53"},
      {"id": "6",   "name": "Saturn",  "gm": "37931184.3"},
      {"id": "7",   "name": "Uranus",  "gm": "5793939.0"},
      {"id": "8",   "name": "Neptune", "gm": "6836529.0"},
    ];
    for (var cfg in bodiesConfig) {
      initial.add(await nasa.fetchBody(cfg["id"]!, cfg["name"]!, t0, t0));
    }

    final Antikythera sim = Antikythera(bodies: initial);
    final BigDec duration = BigDec.fromString("1209600")..setDecimalPrecision(dp); // 15 days

    sim.simulateMotion(durationInSeconds: duration, steps: BigInt.from(50_000), dp: dp);

    final Body sun = sim.getBodyByName("Sun")!;
    for (var b in initial) {
      if (b.name == "Sun") continue;
      
      // Calculate distance relative to the Sun
      final BigDec distAU = b.position.subtract(sun.position, dp: dp).magnitude(dp: dp).divide(auMeters);
      print("${b.name} Distance: ${distAU.toString()} AU");
    }
  });
}