import 'package:big_dec/big_dec.dart';

//Important constants-----------------------------------------------------------------------------------------------------------------------------------------
//EarthMass in Kilograms https://askfilo.com/user-question-answers-smart-solutions/the-mass-of-the-earth-is-5-976-000-000-000-000-000-000-000-3237303235353935
BigDec earthMass = BigDec(
  integer: BigInt.parse("5976000000000000000000000"),
  decimal: BigInt.zero,
  decimalPlaces: 200,
);
//Speed of light (m/s)
BigInt speedOfLight = BigInt.from(299792458);
//Circumference of a circle that takes 1 second for light to travel all the way around
BigDec circumferenceOfASecond = BigDec.fromBigInt(speedOfLight);
//Gravitational constant
BigDec gravitationalConstant = BigDec.fromString("0.0000000000667430");
//Spring constant like analogy to calculate dialation/deformation
BigDec warpConstant = BigDec(
  integer: BigInt.one,
  decimal: BigInt.zero,
  decimalPlaces: 200,
).divide(BigDec.fromBigInt(speedOfLight.pow(2)));
// The Radius of Earth in meters
BigDec earthRadius = BigDec(
  integer: BigInt.from(6371000),
  decimal: BigInt.zero,
  decimalPlaces: 200,
);

//Classes-----------------------------------------------------------------------------------------------------------------------------------------------------

class Vector3{
  Vector3({
    required this.x,
    required this.y,
    required this.z,
  });
  final BigDec x;
  final BigDec y;
  final BigDec z;
  static Vector3 zero = Vector3(
    x: BigDec.fromBigInt(BigInt.zero),
    y: BigDec.fromBigInt(BigInt.zero),
    z: BigDec.fromBigInt(BigInt.zero),
  );
  BigDec magnitude(){
    // Using multiply is safer/faster for squaring
    BigDec x2 = x.multiply(x); 
    BigDec y2 = y.multiply(y);
    BigDec z2 = z.multiply(z);
    
    BigDec scalar = x2.add(y2).add(z2);
    scalar.sqrt(); // This is void, so it's fine
    return scalar;
  }
}
class PotentialEnergy {
  PotentialEnergy({
    required this.vector,
    required this.targetBody,
  });
  final Vector3 vector;
  final Body targetBody;

  BigDec calculateDeformationRatio() {
    // 1. Convert Potential Energy (U) to Potential (Phi)
    // Phi = U / m_target. This isolates the space-time curvature 
    // from the mass of the object sitting in it.
    BigDec phi = vector.magnitude().divide(targetBody.mass); 

    // 2. delta = Phi * (1/c^2)
    BigDec delta = phi.multiply(warpConstant); 

    // 3. ratio = 1 + delta
    BigDec one = BigDec.fromString("1.0");
    one.setDecimalPrecision(200);
    return one.add(delta);
  }
}
class Body{
  Body({
    required this.mass,
    required this.position,
  });
  final BigDec mass;
  final Vector3 position;
  PotentialEnergy calculatePotentialEnergy(Body neighbor, [int decimalPlaces = 200]) {
    // Set precision for constants
    circumferenceOfASecond.setDecimalPrecision(decimalPlaces);
    gravitationalConstant.setDecimalPrecision(decimalPlaces);
    warpConstant.setDecimalPrecision(decimalPlaces);

    // 1. Calculate displacement
    // FIX: You MUST assign the result. subtract() returns a NEW BigDec.
    // Also, avoid .toString() cloning; use the objects directly.
    BigDec dx = position.x.subtract(neighbor.position.x)..setDecimalPrecision(decimalPlaces);
    BigDec dy = position.y.subtract(neighbor.position.y)..setDecimalPrecision(decimalPlaces);
    BigDec dz = position.z.subtract(neighbor.position.z)..setDecimalPrecision(decimalPlaces);

    // 2. Calculate scalar distance r
    // FIX: Assign the result of multiply and add.
    BigDec dx2 = dx.multiply(dx);
    BigDec dy2 = dy.multiply(dy);
    BigDec dz2 = dz.multiply(dz);

    // FIX: distanceSquared must be assigned the result of the addition.
    BigDec distanceSquared = dx2.add(dy2).add(dz2);
    
    // Ensure the scale is correct before sqrt or it might return 0
    distanceSquared.setDecimalPrecision(decimalPlaces);
    distanceSquared.sqrt(); // sqrt is void, so this is correct as-is
    BigDec r = distanceSquared;

    // 3. Scalar Potential Energy: U = -(G * m1 * m2) / r
    // FIX: Every operation (multiply, divide) MUST be assigned back to scalarU.
    BigDec scalarU = gravitationalConstant
        .multiply(mass)
        .multiply(neighbor.mass)
        .divide(r);
    
    // Multiply by -1 to make it negative potential
    scalarU = scalarU.multiply(BigDec.fromString("-1")..setDecimalPrecision(decimalPlaces));

    // 4. Decompose into Vector3 components
    // FIX: Assign the results of divide and multiply.
    BigDec ux = scalarU.multiply(dx.divide(r));
    BigDec uy = scalarU.multiply(dy.divide(r));
    BigDec uz = scalarU.multiply(dz.divide(r));

    return PotentialEnergy(
      vector: Vector3(x: ux, y: uy, z: uz),
      targetBody: neighbor,
    );
  }
}
PotentialEnergy calculateWarpInASystem({
  required List<Body> bodies,
  required Body targetBody,
}){
  Vector3 potentialEnergySum = Vector3.zero;
  for(Body body in bodies){
    PotentialEnergy potentialEnergy = body.calculatePotentialEnergy(targetBody);
    potentialEnergySum = Vector3(
      x: potentialEnergy.vector.x.add(potentialEnergySum.x), 
      y: potentialEnergy.vector.y.add(potentialEnergySum.y),
      z:  potentialEnergy.vector.z.add(potentialEnergySum.z),
    );
  }
  return PotentialEnergy(
    vector: potentialEnergySum, 
    targetBody: targetBody,
  );
}