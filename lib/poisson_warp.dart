import 'package:big_dec/big_dec.dart';

class Vector3 {
  BigDec x, y, z;
  Vector3({required this.x, required this.y, required this.z, int dp = 200}) {
    x.setDecimalPrecision(dp); 
    y.setDecimalPrecision(dp); 
    z.setDecimalPrecision(dp);
  }

  BigDec magnitude({int dp = 200}) => (x.multiply(x).add(y.multiply(y)).add(z.multiply(z))).sqrt()..setDecimalPrecision(dp);
  Vector3 subtract(Vector3 other, {int dp = 200}) => Vector3(x: x.subtract(other.x), y: y.subtract(other.y), z: z.subtract(other.z), dp: dp);
  Vector3 add(Vector3 other, {int dp = 200}) => Vector3(x: x.add(other.x), y: y.add(other.y), z: z.add(other.z), dp: dp);
  Vector3 multiply(BigDec scalar, {int dp = 200}) => Vector3(x: x.multiply(scalar), y: y.multiply(scalar), z: z.multiply(scalar), dp: dp);
}

class Body {
  final String name;
  final BigDec gm; 
  Vector3 position, velocity;
  Body({required this.name, required this.gm, required this.position, required this.velocity});
}

class Antikythera {
  final List<Body> _bodies;
  Antikythera({required List<Body> bodies}) : _bodies = bodies;

  // --------------------------------------------------------------------------
  // CORE SYMPLECTIC EULER INTEGRATOR
  // --------------------------------------------------------------------------
  void simulateMotion({required BigDec durationInSeconds, required BigInt steps, int dp = 200}) {
    BigDec dt = durationInSeconds.divide(BigDec.fromBigInt(steps));

    for (BigInt i = BigInt.zero; i < steps; i += BigInt.one) {
      // 1. Calculate Accelerations based on CURRENT positions
      List<Vector3> accs = _bodies.map((b) => _calculateAcc(b, dp)).toList();

      // 2. THE SYMPLECTIC FLIP: Update Velocity FIRST
      for (int j = 0; j < _bodies.length; j++) {
        _bodies[j].velocity = _bodies[j].velocity.add(accs[j].multiply(dt, dp: dp), dp: dp);
      }

      // 3. Update Position SECOND using the NEWLY updated velocity
      for (int j = 0; j < _bodies.length; j++) {
        _bodies[j].position = _bodies[j].position.add(_bodies[j].velocity.multiply(dt, dp: dp), dp: dp);
      }
    }
  }

  Vector3 _calculateAcc(Body target, int dp) {
    Vector3 totalAcc = Vector3(x: BigDec.fromString("0"), y: BigDec.fromString("0"), z: BigDec.fromString("0"), dp: dp);
    for (var source in _bodies) {
      if (source == target) continue;
      Vector3 rVec = source.position.subtract(target.position, dp: dp);
      BigDec rMag = rVec.magnitude(dp: dp);
      if (rMag.compareTo(BigDec.fromString("0.0001")) > 0) {
        BigDec scalar = source.gm.divide(rMag.multiply(rMag).multiply(rMag));
        totalAcc = totalAcc.add(rVec.multiply(scalar, dp: dp), dp: dp);
      }
    }
    return totalAcc;
  }

  // --------------------------------------------------------------------------
  // UTILITY: BARYCENTER CALCULATION
  // --------------------------------------------------------------------------
  Vector3 calculateBarycenter(int dp) {
    Vector3 weightedPos = Vector3(x: BigDec.fromString("0"), y: BigDec.fromString("0"), z: BigDec.fromString("0"), dp: dp);
    BigDec totalGM = BigDec.fromString("0")..setDecimalPrecision(dp);
    
    for (var body in _bodies) {
      weightedPos = weightedPos.add(body.position.multiply(body.gm, dp: dp), dp: dp);
      totalGM = totalGM.add(body.gm);
    }
    
    return Vector3(
      x: weightedPos.x.divide(totalGM),
      y: weightedPos.y.divide(totalGM),
      z: weightedPos.z.divide(totalGM),
      dp: dp,
    );
  }

  Body? getBodyByName(String name) => _bodies.where((b) => b.name == name).firstOrNull;
  List<Body> get getBodies => _bodies;
}