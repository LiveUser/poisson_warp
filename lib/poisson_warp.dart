import 'package:big_dec/big_dec.dart';
import 'package:power_plant/power_plant.dart';

// --- Important constants (Restored) ---

BigDec earthMass = BigDec(
  integer: BigInt.parse("5976000000000000000000000"),
  decimal: BigInt.zero,
  decimalPlaces: 200,
);
BigInt speedOfLight = BigInt.from(299792458);
BigDec circumferenceOfASecond = BigDec.fromBigInt(speedOfLight);
BigDec gravitationalConstant = BigDec.fromString("0.0000000000667430");
BigDec warpConstant = BigDec(
  integer: BigInt.one,
  decimal: BigInt.zero,
  decimalPlaces: 200,
).divide(BigDec.fromBigInt(speedOfLight.pow(2)));
BigDec earthRadius = BigDec(
  integer: BigInt.from(6371000),
  decimal: BigInt.zero,
  decimalPlaces: 200,
);

// --- Classes (Restored) ---

class Vector3 {
  Vector3({required this.x, required this.y, required this.z});
  final BigDec x;
  final BigDec y;
  final BigDec z;
  static Vector3 zero = Vector3(
    x: BigDec.fromBigInt(BigInt.zero),
    y: BigDec.fromBigInt(BigInt.zero),
    z: BigDec.fromBigInt(BigInt.zero),
  );
  BigDec magnitude() {
    BigDec x2 = x.multiply(x);
    BigDec y2 = y.multiply(y);
    BigDec z2 = z.multiply(z);
    BigDec scalar = x2.add(y2).add(z2);
    scalar.setDecimalPrecision(200);
    scalar.sqrt();
    return scalar;
  }
}

class PotentialEnergy {
  PotentialEnergy({required this.vector, required this.targetBody});
  final Vector3 vector;
  final Body targetBody;

  BigDec calculateDeformationRatio() {
    BigDec phi = vector.magnitude().divide(targetBody.mass);
    BigDec delta = phi.multiply(warpConstant);
    BigDec one = BigDec.fromString("1.0");
    one.setDecimalPrecision(200);
    return one.add(delta);
  }
}

class Body {
  Body({required this.mass, required this.position}) : uuid = uniqueAlphanumeric(tokenLength: 40);
  final BigDec mass;
  final Vector3 position;
  final String uuid;

  PotentialEnergy calculatePotentialEnergy(Body neighbor, [int decimalPlaces = 200]) {
    circumferenceOfASecond.setDecimalPrecision(decimalPlaces);
    gravitationalConstant.setDecimalPrecision(decimalPlaces);
    warpConstant.setDecimalPrecision(decimalPlaces);

    BigDec dx = position.x.subtract(neighbor.position.x)..setDecimalPrecision(decimalPlaces);
    BigDec dy = position.y.subtract(neighbor.position.y)..setDecimalPrecision(decimalPlaces);
    BigDec dz = position.z.subtract(neighbor.position.z)..setDecimalPrecision(decimalPlaces);

    BigDec dx2 = dx.multiply(dx);
    BigDec dy2 = dy.multiply(dy);
    BigDec dz2 = dz.multiply(dz);

    BigDec distanceSquared = dx2.add(dy2).add(dz2);
    distanceSquared.setDecimalPrecision(decimalPlaces);
    distanceSquared.sqrt();
    BigDec r = distanceSquared;

    BigDec scalarU = gravitationalConstant.multiply(mass).multiply(neighbor.mass).divide(r);
    scalarU = scalarU.multiply(BigDec.fromString("-1")..setDecimalPrecision(decimalPlaces));

    BigDec ux = scalarU.multiply(dx.divide(r));
    BigDec uy = scalarU.multiply(dy.divide(r));
    BigDec uz = scalarU.multiply(dz.divide(r));

    return PotentialEnergy(vector: Vector3(x: ux, y: uy, z: uz), targetBody: neighbor);
  }
}

PotentialEnergy calculateWarpInASystem({required List<Body> bodies, required Body targetBody}) {
  Vector3 potentialEnergySum = Vector3.zero;
  for (Body body in bodies) {
    if (targetBody.uuid != body.uuid) {
      PotentialEnergy potentialEnergy = body.calculatePotentialEnergy(targetBody);
      potentialEnergySum = Vector3(
        x: potentialEnergy.vector.x.add(potentialEnergySum.x),
        y: potentialEnergy.vector.y.add(potentialEnergySum.y),
        z: potentialEnergy.vector.z.add(potentialEnergySum.z),
      );
    }
  }
  return PotentialEnergy(vector: potentialEnergySum, targetBody: targetBody);
}

// --- UPDATED Motion & KinematicBody ---

class Motion {
  Motion({
    required this.semiMajorAxis,
    required this.eccentricity,
    required this.periodInSeconds,
    required this.timeOfPeriapsisPassage,
    required this.clockWise,
    required this.zAngle,
  });

  final BigDec semiMajorAxis;
  final BigDec eccentricity;
  final BigDec periodInSeconds;
  final BigDec timeOfPeriapsisPassage;
  final bool clockWise;
  final BigDec zAngle;

  BigDec _bigDecSin(BigDec x, [int terms = 20]) {
    BigDec result = BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(200);
    BigDec xN = BigDec(integer: x.integer, decimal: x.decimal, decimalPlaces: 200);
    BigInt factorial = BigInt.one;
    for (int n = 0; n < terms; n++) {
      int power = 2 * n + 1;
      if (n > 0) {
        factorial *= BigInt.from(power * (power - 1));
        xN = xN.multiply(x).multiply(x);
      }
      BigDec term = xN.divide(BigDec.fromBigInt(factorial));
      result = (n % 2 == 1) ? result.subtract(term) : result.add(term);
    }
    return result;
  }

  BigDec _bigDecCos(BigDec x, [int terms = 20]) {
    BigDec result = BigDec.fromString("1.0")..setDecimalPrecision(200);
    BigDec xN = BigDec.fromString("1.0")..setDecimalPrecision(200);
    BigInt factorial = BigInt.one;
    for (int n = 1; n < terms; n++) {
      int power = 2 * n;
      factorial *= BigInt.from(power * (power - 1));
      xN = xN.multiply(x).multiply(x);
      BigDec term = xN.divide(BigDec.fromBigInt(factorial));
      result = (n % 2 == 1) ? result.subtract(term) : result.add(term);
    }
    return result;
  }

  BigDec _solveKepler(BigDec M, BigDec e) {
    BigDec E = BigDec(integer: M.integer, decimal: M.decimal, decimalPlaces: 200);
    for (int i = 0; i < 5; i++) {
      BigDec numerator = E.subtract(e.multiply(_bigDecSin(E))).subtract(M);
      BigDec one = BigDec.fromString("1.0")..setDecimalPrecision(200);
      BigDec denominator = one.subtract(e.multiply(_bigDecCos(E)));
      E = E.subtract(numerator.divide(denominator));
    }
    return E;
  }

  Vector3 getPositionAtTime(BigDec t) {
    final zero = BigDec.fromBigInt(BigInt.zero);
    final two = BigDec.fromString("2.0")..setDecimalPrecision(200);
    final pi = BigDec.fromString("3.1415926535897932384626433832795028841971")..setDecimalPrecision(200);

    // 1. Calculate time since the last Periapsis passage
    BigDec timeSincePeriapsis = t.subtract(timeOfPeriapsisPassage);

    // 2. CLIP VALUES: Keep time within [0, periodInSeconds]
    // This is essentially: timeSincePeriapsis %= periodInSeconds
    if (timeSincePeriapsis.integer >= periodInSeconds.integer) {
      // Calculate how many full orbits have passed (n = t / period)
      BigDec fullOrbits = timeSincePeriapsis.divide(periodInSeconds);
      
      // Use floor() to get the integer number of completed laps
      fullOrbits.floor(); 
      
      // Subtract (n * period) from the time to get the remainder
      BigDec timeToSubtract = fullOrbits.multiply(periodInSeconds);
      timeSincePeriapsis = timeSincePeriapsis.subtract(timeToSubtract);
    }

    // 3. Calculate Mean Anomaly (M)
    // M = (2 * pi / T) * normalized_time
    BigDec meanMotion = two.multiply(pi).divide(periodInSeconds);
    BigDec M = meanMotion.multiply(timeSincePeriapsis);

    // 4. Solve Kepler's Equation for Eccentric Anomaly (E)
    BigDec E = _solveKepler(M, eccentricity);
    BigDec cosE = _bigDecCos(E);
    BigDec sinE = _bigDecSin(E);

    // 5. Calculate Orbital Plane Position
    BigDec xOrb = semiMajorAxis.multiply(cosE.subtract(eccentricity));
    
    // bFactor = sqrt(1 - e^2)
    BigDec e2 = eccentricity.multiply(eccentricity);
    BigDec bFactor = BigDec.fromString("1.0")..setDecimalPrecision(200);
    bFactor = bFactor.subtract(e2);
    bFactor.sqrt();

    BigDec zOrb = semiMajorAxis.multiply(bFactor).multiply(sinE);

    // 6. Return position (Assuming flat XZ plane for 2D Flutter simulation)
    return Vector3(x: xOrb, y: zero, z: zOrb);
  }
}

class KinematicBody {
  KinematicBody({required Body body, required List<Body> influences}) {
    _body = body;
    _influences = influences;
  }
  late Body _body;
  Body get body => _body;
  late final List<Body> _influences;
  Motion? _motion;
  Motion? get motion => _motion;

  void calculateMotion() {
    final zero = BigDec.fromBigInt(BigInt.zero);
    final two = BigDec.fromString("2.0")..setDecimalPrecision(200);
    final pi = BigDec.fromString("3.1415926535897932384626433832795028841971")..setDecimalPrecision(200);

    PotentialEnergy totalWarp = calculateWarpInASystem(bodies: _influences, targetBody: _body);
    BigDec uMag = totalWarp.vector.magnitude();
    BigDec phi = uMag.divide(_body.mass);

    BigDec v = BigDec(integer: phi.integer, decimal: phi.decimal, decimalPlaces: 200);
    v.sqrt();

    BigDec r = _body.position.magnitude();
    BigDec period = two.multiply(pi).multiply(r).divide(v);

    _motion = Motion(
      semiMajorAxis: r,
      eccentricity: zero,
      periodInSeconds: period,
      timeOfPeriapsisPassage: zero,
      clockWise: true,
      zAngle: zero,
    );
  }
}