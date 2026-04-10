import 'package:big_dec/big_dec.dart';
import 'package:power_plant/power_plant.dart';

// --- Constants ---

BigDec earthMass = BigDec(
  integer: BigInt.parse("5976000000000000000000000"),
  decimal: BigInt.zero,
  decimalPlaces: 200,
);

BigInt speedOfLight = BigInt.from(299792458);

BigDec gravitationalConstant = BigDec.fromString("0.0000000000667430")
  ..setDecimalPrecision(200);

BigDec warpConstant = BigDec(
  integer: BigInt.one,
  decimal: BigInt.zero,
  decimalPlaces: 200,
).divide(BigDec.fromBigInt(speedOfLight.pow(2)));

// Orbital Angular Velocity: 2 * pi / seconds_in_year
// This ensures that after 1 year, the body has moved 2*pi radians.
BigDec secondsInYear = SolarYear(years: BigDec.fromString("1.0")).asSeconds();
BigDec pi = BigDec.fromString("3.1415926535897932384626433832795028841971693993751058209749445923078164")
  ..setDecimalPrecision(200);

BigDec orbitalAngularVelocityRad = (BigDec.fromString("2.0").multiply(pi)).divide(secondsInYear);

// --- Classes ---

class Vector3 {
  Vector3({required this.x, required this.y, required this.z});
  final BigDec x, y, z;

  static Vector3 zero = Vector3(
    x: BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(200),
    y: BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(200),
    z: BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(200),
  );

  BigDec magnitude() {
    BigDec scalar = x.multiply(x).add(y.multiply(y)).add(z.multiply(z));
    scalar.setDecimalPrecision(200);
    scalar.sqrt();
    return scalar;
  }
}

class Ellipse {
  Ellipse({
    required this.semiMajorAxis,
    required this.eccentricity,
    required this.velocityVector,
    required this.centerOfWarp,
  });

  final BigDec semiMajorAxis;
  final BigDec eccentricity;
  final Vector3 velocityVector;
  final Vector3 centerOfWarp;

  static Ellipse generateEllipse({
    required Body primaryBody,
    required List<Body> externalBodies,
  }) {
    int precision = 200;

    // 1. Calculate the gravitational potential energy vector (The Warp)
    // We still need this for the "localWarp" / deformation ratio.
    PotentialEnergy totalWarp = calculateWarpInASystem(
      bodies: externalBodies, 
      targetBody: primaryBody
    );
    
    // 2. Get the actual physical distance (r) in meters.
    // This is the distance from the Sun at (0,0,0).
    BigDec actualDistanceMeters = primaryBody.position.magnitude();

    // Zero check: If the body is the Sun (at 0,0,0), it shouldn't orbit itself.
    if (actualDistanceMeters.integer == BigInt.zero && actualDistanceMeters.decimal == BigInt.zero) {
      BigDec zeroVal = BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(precision);
      return Ellipse(
        semiMajorAxis: zeroVal, 
        eccentricity: zeroVal, 
        velocityVector: Vector3(x: zeroVal, y: zeroVal, z: zeroVal), 
        centerOfWarp: Vector3(x: zeroVal, y: zeroVal, z: zeroVal)
      );
    }

    // 3. Tangential Velocity Magnitude: v = omega_orbital * r
    BigDec vScalar = orbitalAngularVelocityRad.multiply(actualDistanceMeters);

    // 4. THE DIRECTIONAL FIX: Generate Perpendicular Velocity Vector
    // Instead of using warpVector, we use the position (rx, ry).
    // A vector [x, y] has a perpendicular vector [-y, x].
    BigDec vX = primaryBody.position.y.multiply(BigDec.fromString("-1")..setDecimalPrecision(precision));
    BigDec vY = primaryBody.position.x;
    
    Vector3 vDir = Vector3(x: vX, y: vY, z: BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(precision));
    BigDec vDirMag = vDir.magnitude();
    
    // Normalize the perpendicular direction and scale it by our velocity scalar.
    Vector3 finalVelocity = Vector3(
      x: vX.divide(vDirMag).multiply(vScalar),
      y: vY.divide(vDirMag).multiply(vScalar),
      z: BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(precision),
    );

    // 5. Calculate Space-Time Deformation
    BigDec localWarp = totalWarp.calculateDeformationRatio();
    BigDec one = BigDec.fromString("1.0")..setDecimalPrecision(precision);
    
    BigDec ecc = localWarp.subtract(one);
    if (ecc.toString().contains("-")) {
      ecc = ecc.multiply(BigDec.fromString("-1")..setDecimalPrecision(precision));
    }

    return Ellipse(
      semiMajorAxis: actualDistanceMeters.multiply(localWarp),
      eccentricity: ecc,
      velocityVector: finalVelocity,
      centerOfWarp: totalWarp.vector, // Use the energy vector for the warp center
    );
  }

  Body displaceAlongEllipse({
  required Body currentBody,
  required BigDec absoluteTimeSeconds,
}) {
  int precision = 200;
  
  // theta = omega * t
  // This is the total angle from the starting point (0,0)
  BigDec theta = orbitalAngularVelocityRad.multiply(absoluteTimeSeconds);

  // Calculate position directly from the origin
  BigDec cosTheta = TrigHelper.cos(theta, 100, precision);
  BigDec sinTheta = TrigHelper.sin(theta, 100, precision);

  // x = r * cos(theta), y = r * sin(theta)
  // We use the semiMajorAxis (which contains the space-time warp)
  BigDec newX = semiMajorAxis.multiply(cosTheta);
  BigDec newY = semiMajorAxis.multiply(sinTheta);

  return Body(
    name: currentBody.name,
    mass: currentBody.mass,
    uuid: currentBody.uuid, 
    position: Vector3(x: newX, y: newY, z: currentBody.position.z),
  );
}
}

class TrigHelper {
  static BigDec cos(BigDec x, int terms, int precision) {
    BigDec result = BigDec.fromString("1.0")..setDecimalPrecision(precision);
    BigDec xSquared = x.multiply(x);
    BigDec term = BigDec.fromString("1.0")..setDecimalPrecision(precision);
    for (int i = 1; i <= terms; i++) {
      BigDec divisor = BigDec.fromBigInt(BigInt.from((2 * i - 1) * (2 * i)));
      term = term.multiply(xSquared).divide(divisor);
      if (i % 2 == 1) result = result.subtract(term);
      else result = result.add(term);
    }
    return result;
  }

  static BigDec sin(BigDec x, int terms, int precision) {
    BigDec result = x..setDecimalPrecision(precision);
    BigDec xSquared = x.multiply(x);
    BigDec term = x;
    for (int i = 1; i <= terms; i++) {
      BigDec divisor = BigDec.fromBigInt(BigInt.from((2 * i) * (2 * i + 1)));
      term = term.multiply(xSquared).divide(divisor);
      if (i % 2 == 1) result = result.subtract(term);
      else result = result.add(term);
    }
    return result;
  }
}

class PotentialEnergy {
  PotentialEnergy({required this.vector, required this.targetBody});
  final Vector3 vector;
  final Body targetBody;

  BigDec calculateDeformationRatio() {
    BigDec phi = vector.magnitude().divide(targetBody.mass); 
    BigDec delta = phi.multiply(warpConstant); 
    return (BigDec.fromString("1.0")..setDecimalPrecision(200)).add(delta);
  }
}

class Body {
  Body({
    required this.name,
    required this.mass,
    required this.position,
    String? uuid,
  }) : uuid = uuid ?? uniqueAlphanumeric(tokenLength: 40);

  final String name;
  final BigDec mass;
  final Vector3 position;
  final String uuid;

  PotentialEnergy calculatePotentialEnergy(Body neighbor, [int decimalPlaces = 200]) {
    BigDec dx = position.x.subtract(neighbor.position.x)..setDecimalPrecision(decimalPlaces);
    BigDec dy = position.y.subtract(neighbor.position.y)..setDecimalPrecision(decimalPlaces);
    BigDec dz = position.z.subtract(neighbor.position.z)..setDecimalPrecision(decimalPlaces);

    BigDec distanceSquared = dx.multiply(dx).add(dy.multiply(dy)).add(dz.multiply(dz));
    distanceSquared.setDecimalPrecision(decimalPlaces);
    distanceSquared.sqrt();
    BigDec r = distanceSquared;

    BigDec scalarU = gravitationalConstant.multiply(mass).multiply(neighbor.mass).divide(r);
    scalarU = scalarU.multiply(BigDec.fromString("-1")..setDecimalPrecision(decimalPlaces));

    return PotentialEnergy(
      vector: Vector3(
        x: scalarU.multiply(dx.divide(r)),
        y: scalarU.multiply(dy.divide(r)),
        z: scalarU.multiply(dz.divide(r)),
      ),
      targetBody: neighbor,
    );
  }
}

PotentialEnergy calculateWarpInASystem({
  required List<Body> bodies,
  required Body targetBody,
}) {
  Vector3 potentialEnergySum = Vector3.zero;
  for (Body body in bodies) {
    if (body.uuid != targetBody.uuid) {
      PotentialEnergy pe = body.calculatePotentialEnergy(targetBody);
      potentialEnergySum = Vector3(
        x: pe.vector.x.add(potentialEnergySum.x), 
        y: pe.vector.y.add(potentialEnergySum.y),
        z: pe.vector.z.add(potentialEnergySum.z),
      );
    }
  }
  return PotentialEnergy(vector: potentialEnergySum, targetBody: targetBody);
}

class Antikythera {
  Antikythera({required List<Body> bodies}) : _bodies = bodies;
  List<Body> _bodies;

  void simulate({required BigDec secondsOfDisplacements, required BigInt steps}) {
  BigDec stepSize = secondsOfDisplacements.divide(BigDec.fromBigInt(steps));
  
  // Track total time from the start of the simulation
  BigDec totalTimeFromStart = BigDec.fromBigInt(BigInt.zero)..setDecimalPrecision(200);

  for (BigInt step = BigInt.zero; step < steps; step += BigInt.one) {
    totalTimeFromStart = totalTimeFromStart.add(stepSize);
    List<Body> nextState = [];

    for (int i = 0; i < _bodies.length; i++) {
      Ellipse ellipse = Ellipse.generateEllipse(
        primaryBody: _bodies[i], 
        externalBodies: _bodies,
      );

      // Pass the TOTAL TIME, not the step size
      nextState.add(ellipse.displaceAlongEllipse(
        currentBody: _bodies[i], 
        absoluteTimeSeconds: totalTimeFromStart,
      ));
    }
    _bodies = nextState;
  }
}

  Body? getBodyByName(String name) => _bodies.cast<Body?>().firstWhere((b) => b?.name == name, orElse: () => null);
}

class SolarYear {
  SolarYear({required this.years});
  final BigDec years;

  BigDec asSeconds() {
    BigDec d = BigDec.fromString("365.242189")..setDecimalPrecision(200);
    return years.multiply(d).multiply(BigDec.fromString("86400.0")..setDecimalPrecision(200));
  }
}