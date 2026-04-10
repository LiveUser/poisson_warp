# Poisson Warp
A library inspired by poisson's ratio to calculate the relative factor at which time ticks in different bodies in the cosmos. Hecho en Puerto Rico por Radamés Jomuel Valentín Reyes con la ayuda de Gemini.
## Calculating how faster time ticks for the ISS relative to the Earth
~~~dart
Body earth = Body(
  mass: earthMass,
  position: Vector3.zero,
);
// The distance from the earth's center of mass to the ISS
BigInt issDistanceFromEarthInMeters = BigInt.from(6791) * BigInt.from(1000);
Body internationalSpaceStation = Body(
  mass: BigDec.fromBigInt(BigInt.from(419725)), 
  position: Vector3(
    x: BigDec.fromBigInt(issDistanceFromEarthInMeters), 
    y: BigDec.fromBigInt(BigInt.zero), 
    z: BigDec.fromBigInt(BigInt.zero),
  ),
);
print("Time is x${earth.calculatePotentialEnergy(internationalSpaceStation).calculateDeformationRatio().toString()} in the ISS relative to the Earth.");
~~~
## Calculating the ratio difference of the Earth and the Moon relative to the Sun.
~~~dart
Body sun = Body(
  mass: sunMass, // Sun Mass
  position: Vector3.zero, // Sun Position (Zero)
);
Body mercury = Body(
  mass: BigDec.fromString("330104000000000000000000.0"),
  position: Vector3(x: BigDec.fromString("57909227000.0"), y: BigDec.fromBigInt(BigInt.zero), z: BigDec.fromBigInt(BigInt.zero)),
);
Body venus = Body(
  mass: BigDec.fromString("4867320000000000000000000.0"),
  position: Vector3(x: BigDec.fromString("108209475000.0"), y: BigDec.fromBigInt(BigInt.zero), z: BigDec.fromBigInt(BigInt.zero)),
);
Body earth = Body(
  mass: earthMass,
  position: Vector3(x: BigDec.fromString("149598262000.0"), y: BigDec.fromBigInt(BigInt.zero), z: BigDec.fromBigInt(BigInt.zero)),
);
Body moon = Body(
  mass: BigDec.fromString("73420000000000000000000.0"),
  position: Vector3(
    x: earth.position.x.add(BigDec.fromString("384400000.0")), 
    y: BigDec.fromBigInt(BigInt.zero), 
    z: BigDec.fromBigInt(BigInt.zero)
  ),
);
moon.mass.setDecimalPrecision(200);
Body mars = Body(
  mass: BigDec.fromString("641693000000000000000000.0"),
  position: Vector3(x: BigDec.fromString("227943824000.0"), y: BigDec.fromBigInt(BigInt.zero), z: BigDec.fromBigInt(BigInt.zero)),
);
Body jupiter = Body(
  mass: BigDec.fromString("1898130000000000000000000000.0"),
  position: Vector3(x: BigDec.fromString("778340821000.0"), y: BigDec.fromBigInt(BigInt.zero), z: BigDec.fromBigInt(BigInt.zero)),
);
Body saturn = Body(
  mass: BigDec.fromString("56831900000000000000000000.0"),
  position: Vector3(x: BigDec.fromString("1426666422000.0"), y: BigDec.fromBigInt(BigInt.zero), z: BigDec.fromBigInt(BigInt.zero)),
);
Body uranus = Body(
  mass: BigDec.fromString("8681030000000000000000000.0"),
  position: Vector3(x: BigDec.fromString("2870658186000.0"), y: BigDec.fromBigInt(BigInt.zero), z: BigDec.fromBigInt(BigInt.zero)),
);
Body neptune = Body(
  mass: BigDec.fromString("102410000000000000000000000.0"),
  position: Vector3(x: BigDec.fromString("4498396441000.0"), y: BigDec.fromBigInt(BigInt.zero), z: BigDec.fromBigInt(BigInt.zero)),
);
List<Body> solarSystemBodies = [
  sun, 
  mercury, 
  venus, 
  //earth, 
  moon, 
  mars, 
  jupiter, 
  saturn, 
  uranus, 
  neptune,
];
List<Body> solarSystemBodies2 = [
  sun, 
  mercury, 
  venus, 
  earth, 
  //moon, 
  mars, 
  jupiter, 
  saturn, 
  uranus, 
  neptune,
];
PotentialEnergy potentialEnergy1 = calculateWarpInASystem(
  bodies: solarSystemBodies, 
  targetBody: earth,
);
PotentialEnergy potentialEnergy2 = calculateWarpInASystem(
  bodies: solarSystemBodies2, 
  targetBody: moon,
);
BigDec deformationRatio1 = potentialEnergy1.calculateDeformationRatio();
BigDec deformationRatio2 = potentialEnergy2.calculateDeformationRatio();
BigDec difference = deformationRatio2.subtract(deformationRatio1);
print("Time on the moon is x${difference.toString()} faster than the earth.");
~~~
## Motion
~~~dart
Antikythera antikythera = Antikythera(
  bodies: solarSystem,
);
SolarYear solarYear = SolarYear(years: BigDec.fromString("0.5"));
antikythera.simulate(
  secondsOfDisplacements: solarYear.asSeconds(),
  steps: BigInt.from(5000),
);
Body? displacedEarth = antikythera.getBodyByName("Earth");
if(displacedEarth != null){
  print("Earth after ${solarYear.years.toString()} Solar Years");
  print("x: ${displacedEarth.position.x.toString()}");
  print("y: ${displacedEarth.position.y.toString()}");
  print("z: ${displacedEarth.position.z.toString()}");
}
~~~