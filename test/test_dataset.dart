import 'package:big_dec/big_dec.dart';
import 'package:poisson_warp/poisson_warp.dart';

// Helper for zero
final zero = BigDec.fromBigInt(BigInt.zero);
// --- NASA Dataset Values ---
final sunMass = BigDec.fromString("1.989e30".replaceAll("e30", "000000000000000000000000000000"));
// 1. Initialize the Sun at Origin
Body sun = Body(mass: sunMass, position: Vector3(x: zero, y: zero, z: zero));
// 2. Earth on the Positive X-axis
final earthMassVal = BigDec.fromString("5.972e24".replaceAll("e24", "000000000000000000000000"));
final earthDist = BigDec.fromString("149600000000");

Body earth = Body(
  mass: earthMassVal,
  position: Vector3(x: earthDist, y: zero, z: zero),
);
// 3. The Moon (Assume it's currently at a 90-degree angle to the Sun-Earth line for variety)
// This puts it at the same X as Earth, but shifted in Z
final moonMass = BigDec.fromString("7.342e22".replaceAll("e22", "0000000000000000000000"));
final moonDistFromEarth = BigDec.fromString("384400000");

Body moon = Body(
  mass: moonMass,
  position: Vector3(x: earthDist, y: zero, z: moonDistFromEarth),
);
// 4. Other Bodies in respective positions (Approximate snapshot for a realistic spread)
// Mercury (Closer to Sun, shifted in Z)
Body mercury = Body(
  mass: BigDec.fromString("3.301e23".replaceAll("e23", "00000000000000000000000")),
  position: Vector3(x: BigDec.fromString("40000000000"), y: zero, z: BigDec.fromString("41000000000")),
);
// Venus (Shifted to negative X, positive Z)
Body venus = Body(
  mass: BigDec.fromString("4.867e24".replaceAll("e24", "000000000000000000000000")),
  position: Vector3(x: BigDec.fromString("-70000000000"), y: zero, z: BigDec.fromString("82000000000")),
);
// Jupiter (Far out, negative Z)
Body jupiter = Body(
  mass: BigDec.fromString("1.898e27".replaceAll("e27", "000000000000000000000000000")),
  position: Vector3(x: BigDec.fromString("400000000000"), y: zero, z: BigDec.fromString("-660000000000")),
);
// Saturn (Opposite side of the Sun)
Body saturn = Body(
  mass: BigDec.fromString("5.683e26".replaceAll("e26", "00000000000000000000000000")),
  position: Vector3(x: BigDec.fromString("-1200000000000"), y: zero, z: BigDec.fromString("-700000000000")),
);

List<Body> solarSystem = [sun, mercury, venus, earth, moon, jupiter, saturn];