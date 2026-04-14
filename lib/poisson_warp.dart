import 'package:big_dec/big_dec.dart';

class Vector3 {
  BigDec x, y, z;
  Vector3({required this.x, required this.y, required this.z, int decimalPrecision = 200}) {
    x.setDecimalPrecision(decimalPrecision); 
    y.setDecimalPrecision(decimalPrecision); 
    z.setDecimalPrecision(decimalPrecision);
  }

  BigDec magnitude({int decimalPrecision = 200}) => (x.multiply(x).add(y.multiply(y)).add(z.multiply(z))).sqrt()..setDecimalPrecision(decimalPrecision);
  Vector3 subtract(Vector3 other, {int decimalPrecision = 200}) => Vector3(x: x.subtract(other.x), y: y.subtract(other.y), z: z.subtract(other.z), decimalPrecision: decimalPrecision);
  Vector3 add(Vector3 other, {int decimalPrecision = 200}) => Vector3(x: x.add(other.x), y: y.add(other.y), z: z.add(other.z), decimalPrecision: decimalPrecision);
  Vector3 multiply(BigDec scalar, {int decimalPrecision = 200}) => Vector3(x: x.multiply(scalar), y: y.multiply(scalar), z: z.multiply(scalar), decimalPrecision: decimalPrecision);
  // Needed for Frame-Dragging (J x r)
  Vector3 crossProduct(Vector3 other, {int decimalPrecision = 200}) {
    return Vector3(
      x: y.multiply(other.z).subtract(z.multiply(other.y)),
      y: z.multiply(other.x).subtract(x.multiply(other.z)),
      z: x.multiply(other.y).subtract(y.multiply(other.x)),
      decimalPrecision: decimalPrecision,
    );
  }
}

class Body {
  final String name;
  final BigDec gm; 
  BigDec radius;
  BigDec axialVelocityInDegreesPerSecond;
  Vector3 position, velocity;
  Body({
    required this.name, 
    required this.gm, 
    required this.position, 
    required this.velocity,
    required this.axialVelocityInDegreesPerSecond,
    required this.radius,
  });
}

class Antikythera {
  final List<Body> _bodies;
  Antikythera({required List<Body> bodies}) : _bodies = bodies;

  // --------------------------------------------------------------------------
  // CORE SYMPLECTIC EULER INTEGRATOR
  // --------------------------------------------------------------------------
  void simulateMotion({
    required BigDec durationInSeconds, 
    required Function(BigInt stepsSimulated) onStep,
    required BigInt steps, int decimalPrecision = 200,
  }) {
    BigDec dt = durationInSeconds.divide(BigDec.fromBigInt(steps));

    for (BigInt i = BigInt.zero; i < steps; i += BigInt.one) {
      // 1. Calculate Accelerations based on CURRENT positions
      List<Vector3> accs = _bodies.map((b) => _calculateAcc(b,decimalPrecision)).toList();

      // 2. THE SYMPLECTIC FLIP: Update Velocity FIRST
      for (int j = 0; j < _bodies.length; j++) {
        _bodies[j].velocity = _bodies[j].velocity.add(accs[j].multiply(dt, decimalPrecision: decimalPrecision), decimalPrecision: decimalPrecision);
      }

      // 3. Update Position SECOND using the NEWLY updated velocity
      for (int j = 0; j < _bodies.length; j++) {
        _bodies[j].position = _bodies[j].position.add(_bodies[j].velocity.multiply(dt, decimalPrecision: decimalPrecision), decimalPrecision: decimalPrecision);
      }
      onStep(i + BigInt.one);
    }
  }

  Vector3 _calculateAcc(Body target, int decimalPrecision) {
    Vector3 totalAcc = Vector3(x: BigDec.fromString("0"), y: BigDec.fromString("0"), z: BigDec.fromString("0"), decimalPrecision: decimalPrecision);
    
    // Constants for General Relativity logic
    BigDec G = BigDec.fromString("6.67430e-11");
    BigDec c = BigDec.fromString("299792458");
    BigDec cSq = c.multiply(c);

    for (var source in _bodies) {
      if (source == target) continue;

      Vector3 rVec = source.position.subtract(target.position, decimalPrecision: decimalPrecision);
      BigDec rMag = rVec.magnitude(decimalPrecision: decimalPrecision);

      if (rMag.compareTo(BigDec.fromString("0.0001")) > 0) {
        // --- 1. Standard Newtonian Gravity ---
        BigDec rSq = rMag.multiply(rMag);
        BigDec rCubed = rSq.multiply(rMag);
        BigDec scalar = source.gm.divide(rCubed);
        Vector3 newtonianAcc = rVec.multiply(scalar, decimalPrecision: decimalPrecision);
        totalAcc = totalAcc.add(newtonianAcc, decimalPrecision: decimalPrecision);

        // --- 2. The 3D Hole / Warp Acceleration (Frame Dragging) ---
        // We convert degrees/sec to radians/sec and then to Angular Momentum J
        BigDec radsPerSec = source.axialVelocityInDegreesPerSecond.multiply(BigDec.fromString("0.0174533"));
        
        // Approximation of J for a solid sphere: J = 0.4 * M * R^2 * omega
        // Note: Since we use GM, M = GM / G
        BigDec mass = source.gm.divide(G);
        BigDec J_mag = BigDec.fromString("0.4").multiply(mass).multiply(source.radius).multiply(source.radius).multiply(radsPerSec);
        
        // Spin vector (assuming rotation is around Z-axis)
        Vector3 J_vec = Vector3(x: BigDec.fromString("0"), y: BigDec.fromString("0"), z: J_mag, decimalPrecision: decimalPrecision);
        
        // Warp Acc = (2G / c^2 * r^3) * (J x r) x v
        // This creates the "suction" or "drag" in the direction of rotation
        BigDec warpFactor = BigDec.fromString("2").multiply(G).divide(cSq.multiply(rCubed));
        Vector3 dragVector = J_vec.crossProduct(rVec, decimalPrecision: decimalPrecision).multiply(warpFactor, decimalPrecision: decimalPrecision);
        
        // Final "Warp" nudge based on current target velocity
        Vector3 warpAcc = dragVector.crossProduct(target.velocity, decimalPrecision: decimalPrecision);
        totalAcc = totalAcc.add(warpAcc, decimalPrecision: decimalPrecision);
      }
    }
    return totalAcc;
  }

  // --------------------------------------------------------------------------
  // UTILITY: BARYCENTER CALCULATION
  // --------------------------------------------------------------------------
  Vector3 calculateBarycenter(int decimalPrecision) {
    Vector3 weightedecimalPrecisionos = Vector3(x: BigDec.fromString("0"), y: BigDec.fromString("0"), z: BigDec.fromString("0"), decimalPrecision: decimalPrecision);
    BigDec totalGM = BigDec.fromString("0")..setDecimalPrecision(decimalPrecision);
    
    for (var body in _bodies) {
      weightedecimalPrecisionos = weightedecimalPrecisionos.add(body.position.multiply(body.gm, decimalPrecision: decimalPrecision), decimalPrecision: decimalPrecision);
      totalGM = totalGM.add(body.gm);
    }
    
    return Vector3(
      x: weightedecimalPrecisionos.x.divide(totalGM),
      y: weightedecimalPrecisionos.y.divide(totalGM),
      z: weightedecimalPrecisionos.z.divide(totalGM),
      decimalPrecision: decimalPrecision,
    );
  }

  Body? getBodyByName(String name) => _bodies.where((b) => b.name == name).firstOrNull;
  List<Body> get getBodies => _bodies;
}
class SolarYear{
  SolarYear({
    required this.earthYears,
  });
  final BigDec earthYears;
  BigDec inSeconds(){
    BigDec oneYearInSeconds = BigDec.fromString("31556925.216");
    return earthYears.multiply(oneYearInSeconds);
  }
}