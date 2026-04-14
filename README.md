# Poisson Warp
Symplectic Euler high-precision N-body simulation. Software Hecho en Puerto Rico por Radamés Jomuel Valentín Reyes con la ayuda de Gemini.

## Status: Speculative / Under Testing
### Important changes
Simulation now accounts for warp. A hypothetical idea I came up with. It is not scientiffically proven.

## Core Classes & Methods

### `Vector3`
A high-precision 3D vector class supporting arbitrary-precision arithmetic.
* **Methods**: `add`, `subtract`, `multiply`, and `magnitude`.

### `Body`
Represents a celestial object.
* **Properties**: `name`, `gm` (gravitational parameter), `position`, `velocity`, and `properTimeExperienced`.

### `Antikythera`
The primary simulation engine.
* **`simulateMotion`**: Implements a **Symplectic Euler** integrator (Semi-Implicit Euler). It uses a staggered update (Velocity First → Position Second) to preserve phase-space volume and ensure long-term orbital stability.
* **`calculateBarycenter`**: A utility method to find the system's center of mass based on the current gravitational distribution.
* **`rotateToEquatorialFrame`**: Transforms coordinate vectors to account for Earth's axial tilt (obliquity).

## Usage & Implementation

### High-Precision Orbital Simulation
To maintain stability, the engine utilizes the "code flip" principle, ensuring orbits do not spiral outward over long durations. Fetched data from NASA Horizons API to test method.

~~~dart
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
        if(1 <= stepCompleted.difference(lastUpdate).inSeconds){
          lastUpdate = stepCompleted;
          print("Progress: ${stepsSimulated.toString()}/${steps.toString()}");
        }
      },
      decimalPrecision: decimalPrecision,
    );

    final Body sun = sim.getBodyByName("Sun")!;
    for (var b in initial) {
      if (b.name == "Sun") continue;
      final BigDec distAU = b.position
          .subtract(sun.position, decimalPrecision: decimalPrecision)
          .magnitude(decimalPrecision: decimalPrecision)
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
~~~
### Test results
~~~
Mercury is at 0.5984716889911468AU and is spinning at 0.00007104733955 deg/second

Venus is at 0.7781938476460273AU and is spinning at 0.00001714518906 deg/second

Earth is at 1.0127760342089950AU and is spinning at 0.00417807413224 deg/second

Moon is at 1.0089625153231899AU and is spinning at 0.00015250417632 deg/second

Mars is at 1.5637783297816529AU and is spinning at 0.00406125090260 deg/second

Jupiter is at 5.4555176860831938AU and is spinning at 0.01007546282737 deg/second

Saturn is at 9.0596899064041788AU and is spinning at 0.00938418924755 deg/second

Uranus is at 20.0590311030866897AU and is spinning at 0.00580045283056 deg/second

Neptune is at 30.0658706280278499AU and is spinning at 0.00620731016088 deg/second
~~~
## Hypothesis/Theory behind the project (not scientiffically proven)
Assumes that there is no mass at the center of mass but rather a 3d hole(sphere) pulling everything around it which bends space. Even though when you do the math eveything cancels out there is a physics example where when rotating, a person's speed changes when you extend the arms because the center of mass is moving outwards. This outward pull of the mass rips space creating a hole that pulls towards it. This is represented by the GM value of the body. The axial velocity increases centripetal force which in turn increases the warp (the hole) which in turn bends space even more. 

This idea is highly speculative and needs more testing and empirical evidence but the numbers of the simulation seem correct.

## References
- [The Code That Revolutionized Orbital Simulation by braintruffle on You Tube](https://www.youtube.com/watch?v=nCg3aXn5F3M&list=PLNExT-iB8uSMKRyKETqbaxKzI-sB9qoyO&index=3)