import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:big_dec/big_dec.dart';
import 'package:test/test.dart';
import 'package:poisson_warp/poisson_warp.dart';

// ============================================================================
// ROBUST SCIENTIFIC NUMBER PARSER FOR NASA HORIZONS
// ============================================================================
BigDec parseHorizonsNumber(String raw) {
  String s = raw.trim();
  if (s.isEmpty) {
    return BigDec.fromString("0")..setDecimalPrecision(200);
  }

  // Remove uncertainty suffixes like "+/- 1.23E-06"
  if (s.contains('+/-')) {
    s = s.split('+/-')[0].trim();
  } else if (s.contains('+-')) {
    s = s.split('+-')[0].trim();
  }

  // Convert Fortran D exponents → E
  s = s.replaceAll('D', 'E').replaceAll('d', 'E');

  // Convert Fortran-style "1.234567-06" → "1.234567E-06"
  if (!s.contains('E') && !s.contains('e')) {
    final match = RegExp(r'^([+-]?[0-9]*\.?[0-9]*)([+-][0-9]+)$')
        .firstMatch(s);
    if (match != null) {
      final coeff = match.group(1)!.isEmpty ? "0" : match.group(1)!;
      final exp = match.group(2)!;
      s = '${coeff}E${exp}';
    }
  }

  return BigDec.fromString(s)..setDecimalPrecision(200);
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

    final Map<String, dynamic> data = jsonDecode(response.body);
    final String resultText = data["result"] ?? "";

    const String soeMarker = "\$\$SOE";
    const String eoeMarker = "\$\$EOE";

    final int soe = resultText.indexOf(soeMarker);
    final int eoe = resultText.indexOf(eoeMarker);

    if (soe < 0 || eoe < 0 || eoe <= soe) {
      throw StateError("Could not locate SOE/EOE in Horizons response.");
    }

    final String tableContent =
        resultText.substring(soe + soeMarker.length, eoe).trim();
    final List<String> lines = tableContent.split('\n');

    if (lines.isEmpty) {
      throw StateError("No ephemeris lines found in Horizons response.");
    }

    final List<String> cols = lines[0].split(',');

    if (cols.length < 8) {
      throw StateError("Unexpected Horizons VECTORS CSV format.");
    }

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
      axialVelocityInDegreesPerSecond: _parseRotationRate(resultText),
    );
  }

  // GM is printed in km^3/s^2 → convert to m^3/s^2 by ×1e9
  BigDec _parseGM(String header) {
    final RegExp r = RegExp(
      r"GM[^=]*=\s*([0-9.Dde+\-]+)",
      caseSensitive: false,
    );
    final Match? m = r.firstMatch(header);
    if (m == null) {
      return BigDec.fromString("132712440018000000000")
        ..setDecimalPrecision(200);
    }
    final BigDec gmKm3 = parseHorizonsNumber(m.group(1)!);
    final BigDec factor = BigDec.fromString("1000000000")
      ..setDecimalPrecision(200);
    return gmKm3.multiply(factor)..setDecimalPrecision(200);
  }

  BigDec _parseRotationRate(String header) {
    final radRegex = RegExp(
      r"(?:Sid\.\s*)?rot\.\s*rate,?\s*\(?rad/s\)?\s*=?\s*([0-9.Dde+\-]+)",
      caseSensitive: false,
    );

    final hourRegex = RegExp(
      r"(?:Sid\.\s*)?rot\.\s*per(?:iod)?\s*=?\s*([0-9.Dde+\-]+)\s*h",
      caseSensitive: false,
    );

    final radMatch = radRegex.firstMatch(header);
    if (radMatch != null) {
      final BigDec radPerSec = parseHorizonsNumber(radMatch.group(1)!);
      final BigDec radToDeg =
          BigDec.fromString("57.29577951308232")..setDecimalPrecision(200);
      return radPerSec.multiply(radToDeg).abs()..setDecimalPrecision(200);
    }

    final hourMatch = hourRegex.firstMatch(header);
    if (hourMatch != null) {
      BigDec hours = parseHorizonsNumber(hourMatch.group(1)!);
      if (hours.compareTo(BigDec.fromString("0")) == 0) {
        return BigDec.fromString("0")..setDecimalPrecision(200);
      }
      final BigDec secondsPerHour =
          BigDec.fromString("3600")..setDecimalPrecision(200);
      final BigDec totalSeconds =
          hours.multiply(secondsPerHour)..setDecimalPrecision(200);
      final BigDec fullCircle =
          BigDec.fromString("360")..setDecimalPrecision(200);
      return fullCircle.divide(totalSeconds)..setDecimalPrecision(200);
    }

    return BigDec.fromString("0")..setDecimalPrecision(200);
  }
}

// ============================================================================
// TEST SUITE
// ============================================================================
void main() {
  // --------------------------------------------------------------------------
  // SOLAR SYSTEM TEST
  // --------------------------------------------------------------------------
  test("Symplectic Solar System Distance Check", () async {
    final nasa = NASAHorizonsService();
    const int decimalPrecision = 200;

    final BigDec auMeters =
        BigDec.fromString("149597870700")..setDecimalPrecision(decimalPrecision);

    final DateTime t0 = DateTime(2005, 1, 1);
    final List<Body> initial = [];

    final bodiesConfig = [
      {"id": "10", "name": "Sun"},
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

    final Antikythera sim = Antikythera(
      bodies: initial,
      decimalPrecision: decimalPrecision,
      centralBody: initial.firstWhere((b) => b.name == "Sun"),
      earthReferenceBody: initial.firstWhere((b) => b.name == "Earth"),
    );

    final BigDec simulationDays =
        BigDec.fromString("14")..setDecimalPrecision(decimalPrecision);
    final BigDec secondsInDay =
        BigDec.fromString("86400")..setDecimalPrecision(decimalPrecision);
    final BigDec durationInSeconds =
        (simulationDays * secondsInDay)..setDecimalPrecision(decimalPrecision);

    final BigInt steps = BigInt.from(25_000);

    DateTime lastUpdate = DateTime.now();

    sim.simulateMotion(
      durationInSeconds: durationInSeconds,
      steps: steps,
      onStep: (stepsSimulated) {
        DateTime now = DateTime.now();
        if (now.difference(lastUpdate).inSeconds >= 5) {
          lastUpdate = now;
          print("Progress: $stepsSimulated/$steps");
        }
      },
    );

    final Body sun = sim.getBodyByName("Sun");
    for (var b in sim.bodies) {
      if (b.name == "Sun") continue;
      final BigDec distMeters =
          b.position.subtract(sun.position).magnitude()
            ..setDecimalPrecision(decimalPrecision);
      final BigDec distAU =
          distMeters.divide(auMeters)..setDecimalPrecision(decimalPrecision);
      final BigDec tick =
          sim.computeTickFactorForBody(b)..setDecimalPrecision(decimalPrecision);
      print(
        "${b.name} is at ${distAU.toString()} AU "
        "and spinning at ${b.axialVelocityInDegreesPerSecond.toString()} "
        "and time ticks x${tick.toString()} relative to the earth",
      );
    }
  });

  // --------------------------------------------------------------------------
  // AXIAL VELOCITY TEST
  // --------------------------------------------------------------------------
  test("Verify axial velocity calculations", () async {
    final nasa = NASAHorizonsService();
    final DateTime t0 = DateTime(2005, 1, 1);
    final List<Body> initial = [];

    final bodiesConfig = [
      {"id": "10", "name": "Sun"},
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
      print("- ${body.name} spin = ${body.axialVelocityInDegreesPerSecond}");
    }
  });

  // --------------------------------------------------------------------------
  // BLACK HOLE TEST
  // --------------------------------------------------------------------------
  test("Warp model around a supermassive black hole", () async {
    const int decimalPrecision = 200;

    final BigDec gmBH =
        BigDec.fromString("5.3e26")..setDecimalPrecision(decimalPrecision);
    final BigDec spinBH =
        BigDec.fromString("0.05")..setDecimalPrecision(decimalPrecision);

    final Body blackHole = Body(
      name: "BH",
      gm: gmBH,
      position: Vector3(
        x: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
        y: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
        z: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
      ),
      velocity: Vector3(
        x: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
        y: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
        z: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
      ),
      axialVelocityInDegreesPerSecond: spinBH,
    );

    Body makeStar({
      required String name,
      required String rMeters,
      required String vMetersPerSec,
    }) {
      final BigDec r =
          BigDec.fromString(rMeters)..setDecimalPrecision(decimalPrecision);
      final BigDec v =
          BigDec.fromString(vMetersPerSec)..setDecimalPrecision(decimalPrecision);

      return Body(
        name: name,
        gm: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
        position: Vector3(
          x: r,
          y: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
          z: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
        ),
        velocity: Vector3(
          x: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
          y: v,
          z: BigDec.fromString("0")..setDecimalPrecision(decimalPrecision),
        ),
        axialVelocityInDegreesPerSecond:
            BigDec.fromString("0.001")..setDecimalPrecision(decimalPrecision),
      );
    }

    final Body starInner = makeStar(
      name: "StarInner",
      rMeters: "1.0e11",
      vMetersPerSec: "2.0e7",
    );

    final Body starMid = makeStar(
      name: "StarMid",
      rMeters: "5.0e11",
      vMetersPerSec: "1.0e7",
    );

    final Body starOuter = makeStar(
      name: "StarOuter",
      rMeters: "1.0e12",
      vMetersPerSec: "7.0e6",
    );

    final List<Body> bodies = [
      blackHole,
      starInner,
      starMid,
      starOuter,
    ];

    final Antikythera sim = Antikythera(
      bodies: bodies,
      decimalPrecision: decimalPrecision,
      centralBody: blackHole,
      earthReferenceBody: starOuter,
    );

    final BigDec durationInSeconds =
        BigDec.fromString("86400")..setDecimalPrecision(decimalPrecision);

    final BigInt steps = BigInt.from(20000);

    DateTime lastUpdate = DateTime.now();

    sim.simulateMotion(
      durationInSeconds: durationInSeconds,
      steps: steps,
      onStep: (stepsSimulated) {
        final DateTime now = DateTime.now();
        if (now.difference(lastUpdate).inSeconds >= 5) {
          lastUpdate = now;
          print("BH Progress: $stepsSimulated/$steps");
        }
      },
    );

    final Body bh = sim.getBodyByName("BH");
    for (final b in sim.bodies) {
      if (b.name == "BH") continue;
      final BigDec dist =
          b.position.subtract(bh.position).magnitude()
            ..setDecimalPrecision(decimalPrecision);
      final BigDec tick =
          sim.computeTickFactorForBody(b)..setDecimalPrecision(decimalPrecision);
      print(
        "${b.name} is at ${dist.toString()} meters "
        "and spinning at ${b.axialVelocityInDegreesPerSecond.toString()} "
        "and time ticks x${tick.toString()} relative to the earth",
      );
    }
  });
}
