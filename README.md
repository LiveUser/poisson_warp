# Poisson Warp
Symplectic Euler high-precision N-body simulation. Software Hecho en Puerto Rico por Radamés Jomuel Valentín Reyes con la ayuda de Gemini.

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
final Antikythera sim = Antikythera(bodies: initial);
final BigDec duration = BigDec.fromString("1209600")..setDecimalPrecision(dp); // 15 days

// Execute Symplectic Integration
sim.simulateMotion(
  durationInSeconds: duration, 
  steps: BigInt.from(50000), 
  decimalPlaces: dp
);
//Expanded Validation Test
//This example demonstrates fetching high-fidelity state vectors from NASA Horizons and validating the simulation against "truth" data.

test("Full System Alignment Validation", () async {
  final nasa = NASAHorizonsService();
  const int dp = 200;

  // Example Configuration including Moons
  final List<Map<String, String>> bodiesConfig = [
    {"id": "10",  "name": "Sun"},
    {"id": "199", "name": "Mercury"},
    {"id": "399", "name": "Earth"},
    {"id": "301", "name": "Moon"},
    {"id": "4",   "name": "Mars Barycenter"},
  ];

  final DateTime t0 = DateTime(2005, 1, 1);
  final List<Body> initial = [];

  for (final cfg in bodiesConfig) {
    initial.add(await nasa.fetchBody(cfg["id"]!, cfg["name"]!, t0, t0));
  }

  final Antikythera sim = Antikythera(bodies: initial);
  final BigDec duration = BigDec.fromString("1209600"); // 15 days

  sim.simulateMotion(durationInSeconds: duration, steps: BigInt.from(100000), decimalPlaces: dp);

  for (var body in initial) {
    print("${body.name} Final Position: ${body.position.x}, ${body.position.y}, ${body.position.z}");
  }
});
~~~
### Test results
~~~
Mercury Distance: 0.598471688991146 AU
Venus Distance: 0.778193847646027 AU
Earth Distance: 1.012776034208995 AU
Moon Distance: 1.008962515323189 AU
Mars Distance: 1.563778329605912 AU
Jupiter Distance: 5.455510629116387 AU
Saturn Distance: 9.059694468740320 AU
Uranus Distance: 20.059031731107295 AU
Neptune Distance: 30.065865881193228 AU
~~~
## References
- [The Code That Revolutionized Orbital Simulation by braintruffle on You Tube](https://www.youtube.com/watch?v=nCg3aXn5F3M&list=PLNExT-iB8uSMKRyKETqbaxKzI-sB9qoyO&index=3)