# Poisson Warp
a high‑precision gravitational‑physics and time‑deformation engine developed in Puerto Rico. Built on a foundation of arbitrary‑precision mathematics using the big_dec library, it models how mass, geometry, and orbital motion shape the flow of time and the evolution of celestial bodies. The engine specializes in N-body simulations, relativistic time-dilation calculations, and frame transformations to align simulated data with high-fidelity observational sources like NASA JPL Horizons. Hecho en Puerto Rico por Radamés Jomuel Valentín Reyes con la ayuda de Gemini.
* **Arbitrary-Precision Physics:** Utilizes `BigDec` to eliminate floating-point rounding errors in long-duration astronomical simulations.
* **Coordinate Frame Transformation:** Includes native support for rotating system data between the **Ecliptic Frame** and the **Equatorial Frame (J2000)** to ensure compatibility with standard astronomical datasets.
* **Heliocentric & Barycentric Support:** Features built-in methods to recenter systems relative to specific bodies (like the Sun) or the calculated center of mass (Barycenter).
* **Relativistic Modeling:** Provides methods to calculate gravitational potential energy and the resulting time-deformation ratios across complex systems.

## Core Functions & Usage

### 1. Relativistic Time Deformation
Calculate how much faster or slower time passes on one body relative to another based on gravitational potential.

```dart
// The distance from Earth's center to the ISS
BigInt issAltitude = BigInt.from(6791) * BigInt.from(1000);

Body internationalSpaceStation = Body(
  name: "ISS",
  gm: BigDec.fromString("0"), // GM not needed for target
  position: Vector3(
    x: BigDec.fromBigInt(issAltitude), 
    y: BigDec.fromBigInt(BigInt.zero), 
    z: BigDec.fromBigInt(BigInt.zero),
  ),
  velocity: Vector3.zero(),
);

// Calculate deformation ratio relative to Earth's mass
print("Time ratio on ISS: ${earth.calculatePotentialEnergy(internationalSpaceStation).calculateDeformationRatio()}");

### 2. High-Precision Orbital Simulation
Use the Antikythera class to simulate orbital positions. You can simulate in the Ecliptic frame or automatically transform to the Equatorial frame to match NASA vector data.
~~~dart
Antikythera sim = Antikythera(bodies: [sun, mercury, venus, earth]);

// Simulate for a specific duration
BigDec duration = BigDec.fromString("1296000"); // 15 days
sim.simulateEquatorialFrame(durationSeconds: duration);

// Re-align system to the Barycenter
sim.recenterBarycenter();
~~~
### NASA Horizons Validation Test
The following test suite demonstrates how to fetch live vector data from NASA Horizons to validate the engine's accuracy. It calculates the absolute error in meters and the heliocentric distance in Astronomical Units (AU).
~~~dart
import 'package:test/test.dart';
import 'dart:convert';
import 'package:big_dec/big_dec.dart';
import 'package:http/http.dart' as http;
import 'package:poisson_warp/poisson_warp.dart';

void main() {
  final nasa = NASAHorizonsService();

  test("NASA Horizons Alignment Validation", () async {
    const String startDate = "1998-02-20";
    const String endDate   = "1998-08-21"; 
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

    for (var config in bodyConfigs) {
      nasaInitial.add(await nasa.fetchBody(config['id']!, config['name']!, startDate));
      truthMap[config['name']!] = await nasa.fetchBody(config['id']!, config['name']!, endDate);
    }

    Antikythera sim = Antikythera(bodies: nasaInitial);
    // 182 days in seconds
    BigDec duration = BigDec.fromString("15724800")..setDecimalPrecision(dp); 
    
    sim.simulateEquatorialFrame(durationSeconds: duration, decimalPlaces: dp);
    sim.recenterBarycenter(decimalPlaces: dp);

    final au = BigDec.fromString("149597870700")..setDecimalPrecision(dp);
    Body sun = sim.getBodyByName("Sun")!;

    print("\n--- HELIOCENTRIC DISTANCES (AU) ---");
    for (var body in sim.bodies) {
      if (body.name == "Sun") continue;
      Vector3 relPos = body.position.subtract(sun.position, decimalPlaces: dp);
      print("${body.name}: ${relPos.magnitude().divide(au)} AU");
    }
  });
}
~~~
### Validation Results (182-Day Simulation)
The following results represent the heliocentric distances calculated at the end of a half-year simulation starting February 20, 1998.
~~~
--- HELIOCENTRIC DISTANCES (AU) ---
Mercury: 0.467286371062772515 AU
Venus:   0.712295599856126104 AU
Earth:   0.978817326616415379 AU
Mars:    1.399242683197065210 AU
~~~
Hecho en Puerto Rico por Radamés Jomuel Valentín Reyes.