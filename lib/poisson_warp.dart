import 'package:big_dec/big_dec.dart';
import 'package:power_plant/power_plant.dart';

// --- Constants ---

final BigInt speedOfLight = BigInt.from(299792458);

// Initialized with high precision for constant-based calculations
final BigDec gravitationalConstant = BigDec.fromString("0.0000000000667430")
  ..setDecimalPrecision(200);

final BigDec warpConstant = (BigDec.fromString("1.0")..setDecimalPrecision(200))
    .divide(BigDec.fromBigInt(speedOfLight.pow(2)));

final BigDec pi = BigDec.fromString("3.1415926535897932384626433832795028841971693993751058209749445923078164")
  ..setDecimalPrecision(200);

// --- Vector Math ---

class Vector3 {
  Vector3({required this.x, required this.y, required this.z});
  BigDec x, y, z;

  static Vector3 zero = Vector3(
    x: BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(200),
    y: BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(200),
    z: BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(200),
  );

  BigDec magnitude() {
    BigDec scalar = x.multiply(x).add(y.multiply(y)).add(z.multiply(z));
    scalar.setDecimalPrecision(200);
    return scalar.sqrt();
  }

  Vector3 add(Vector3 other) => Vector3(
    x: x.add(other.x),
    y: y.add(other.y),
    z: z.add(other.z),
  );

  Vector3 subtract(Vector3 other) => Vector3(
    x: x.subtract(other.x),
    y: y.subtract(other.y),
    z: z.subtract(other.z),
  );

  Vector3 multiplyScalar(BigDec scalar) => Vector3(
    x: x.multiply(scalar),
    y: y.multiply(scalar),
    z: z.multiply(scalar),
  );
}

// --- Body Definition ---

class Body {
  Body({
    required this.name,
    required this.gm, // FIXED: Store GM directly to avoid G division errors
    required this.position,
    required this.velocity,
    String? uuid,
  }) : uuid = uuid ?? uniqueAlphanumeric(tokenLength: 40);

  final String name;
  final BigDec gm; // Standard Gravitational Parameter (m^3/s^2)
  Vector3 position;
  Vector3 velocity; 
  final String uuid;

  Vector3 calculateAcceleration(Body neighbor, [int precision = 200]) {
    Vector3 diff = neighbor.position.subtract(position);
    BigDec rSquared = diff.x.multiply(diff.x).add(diff.y.multiply(diff.y)).add(diff.z.multiply(diff.z));
    BigDec r = rSquared.sqrt();

    // a = GM / r^2
    BigDec accelMag = neighbor.gm.divide(rSquared);

    return Vector3(
      x: accelMag.multiply(diff.x.divide(r)),
      y: accelMag.multiply(diff.y.divide(r)),
      z: accelMag.multiply(diff.z.divide(r)),
    );
  }

  PotentialEnergy calculatePotentialContribution(Body neighbor, [int decimalPlaces = 200]) {
    Vector3 diff = position.subtract(neighbor.position);
    BigDec r = diff.x.multiply(diff.x).add(diff.y.multiply(diff.y)).add(diff.z.multiply(diff.z)).sqrt();

    // Local potential phi = GM / r
    BigDec scalarPhi = neighbor.gm.divide(r);

    return PotentialEnergy(
      vector: Vector3(
        x: scalarPhi.multiply(diff.x.divide(r)),
        y: scalarPhi.multiply(diff.y.divide(r)),
        z: scalarPhi.multiply(diff.z.divide(r)),
      ),
    );
  }
}

// --- Space-Time Model ---

class PotentialEnergy {
  PotentialEnergy({required this.vector});
  final Vector3 vector;

  BigDec calculateDeformationRatio() {
    BigDec phi = vector.magnitude(); 
    BigDec delta = phi.multiply(warpConstant); 
    return (BigDec.fromString("1.0")..setDecimalPrecision(200)).add(delta);
  }
}

class Ellipse {
  Ellipse({required this.semiMajorAxis, required this.angularVelocity});
  final BigDec semiMajorAxis;
  final BigDec angularVelocity;

  static Ellipse generateEllipse({required Body primaryBody, required List<Body> externalBodies}) {
    PotentialEnergy totalWarp = calculateWarpInASystem(bodies: externalBodies, targetBody: primaryBody);
    BigDec r = primaryBody.position.magnitude();
    BigDec v = primaryBody.velocity.magnitude();

    if (r.integer == BigInt.zero && r.decimal == BigInt.zero) {
      return Ellipse(
        semiMajorAxis: BigDec.fromString("0")..setDecimalPrecision(200),
        angularVelocity: BigDec.fromString("0")..setDecimalPrecision(200),
      );
    }

    BigDec omega = v.divide(r);
    BigDec localWarp = totalWarp.calculateDeformationRatio();

    return Ellipse(semiMajorAxis: r.multiply(localWarp), angularVelocity: omega);
  }
}

// --- Integration Engine ---

class Antikythera {
  Antikythera({required List<Body> bodies}) : _bodies = bodies;
  List<Body> _bodies;

  void simulate({required BigDec totalTime, required BigInt steps}) {
    BigDec dt = totalTime.divide(BigDec.fromBigInt(steps));

    for (BigInt step = BigInt.zero; step < steps; step += BigInt.one) {
      List<Body> nextState = [];

      for (int i = 0; i < _bodies.length; i++) {
        Body current = _bodies[i];
        Vector3 netAccel = Vector3.zero;

        for (int j = 0; j < _bodies.length; j++) {
          if (i != j) netAccel = netAccel.add(current.calculateAcceleration(_bodies[j]));
        }

        Vector3 newVelocity = current.velocity.add(netAccel.multiplyScalar(dt));

        Body updatedVelocityBody = Body(
          name: current.name,
          gm: current.gm,
          position: current.position,
          velocity: newVelocity,
          uuid: current.uuid,
        );

        Ellipse ellipse = Ellipse.generateEllipse(primaryBody: updatedVelocityBody, externalBodies: _bodies);

        BigDec theta = ellipse.angularVelocity.multiply(dt);
        BigDec cosTheta = TrigHelper.cos(theta, 50, 200);
        BigDec sinTheta = TrigHelper.sin(theta, 50, 200);

        BigDec nextX = current.position.x.multiply(cosTheta).subtract(current.position.y.multiply(sinTheta));
        BigDec nextY = current.position.x.multiply(sinTheta).add(current.position.y.multiply(cosTheta));

        nextState.add(Body(
          name: current.name,
          gm: current.gm,
          position: Vector3(x: nextX, y: nextY, z: current.position.z),
          velocity: newVelocity,
          uuid: current.uuid,
        ));
      }
      _bodies = nextState;
    }
  }

  Vector3 computeBarycenter() {
    BigDec totalGM = BigDec.fromString("0")..setDecimalPrecision(200);
    BigDec bx = BigDec.fromString("0"), by = BigDec.fromString("0"), bz = BigDec.fromString("0");

    for (final b in _bodies) {
      totalGM = totalGM.add(b.gm);
      bx = bx.add(b.position.x.multiply(b.gm));
      by = by.add(b.position.y.multiply(b.gm));
      bz = bz.add(b.position.z.multiply(b.gm));
    }
    return Vector3(x: bx.divide(totalGM), y: by.divide(totalGM), z: bz.divide(totalGM));
  }

  void recenterToBarycenter() {
    final Vector3 bary = computeBarycenter();
    for (final b in _bodies) {
      b.position = b.position.subtract(bary);
    }
  }

  Body? getBodyByName(String name) => _bodies.cast<Body?>().firstWhere((b) => b?.name == name, orElse: () => null);
}

class TrigHelper {
  static BigDec cos(BigDec x, int terms, int precision) {
    BigDec result = BigDec.fromString("1.0")..setDecimalPrecision(precision);
    BigDec xSq = x.multiply(x), term = BigDec.fromString("1.0")..setDecimalPrecision(precision);
    for (int i = 1; i <= terms; i++) {
      term = term.multiply(xSq).divide(BigDec.fromBigInt(BigInt.from((2 * i - 1) * (2 * i))));
      if (i % 2 == 1) result = result.subtract(term); else result = result.add(term);
    }
    return result;
  }

  static BigDec sin(BigDec x, int terms, int precision) {
    BigDec result = x..setDecimalPrecision(precision);
    BigDec xSq = x.multiply(x), term = x;
    for (int i = 1; i <= terms; i++) {
      term = term.multiply(xSq).divide(BigDec.fromBigInt(BigInt.from((2 * i) * (2 * i + 1))));
      if (i % 2 == 1) result = result.subtract(term); else result = result.add(term);
    }
    return result;
  }
}

PotentialEnergy calculateWarpInASystem({required List<Body> bodies, required Body targetBody}) {
  Vector3 peSum = Vector3.zero;
  for (Body body in bodies) {
    if (body.uuid != targetBody.uuid) {
      peSum = peSum.add(body.calculatePotentialContribution(targetBody).vector);
    }
  }
  return PotentialEnergy(vector: peSum);
}

class SolarYear {
  SolarYear({required this.years});
  final BigDec years;
  BigDec asSeconds() {
    BigDec d = BigDec.fromString("365.242189")..setDecimalPrecision(200);
    return years.multiply(d).multiply(BigDec.fromString("86400.0")..setDecimalPrecision(200));
  }
}