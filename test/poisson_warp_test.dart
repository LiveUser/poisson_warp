import 'package:big_dec/big_dec.dart';
import 'package:test/test.dart';
import 'package:poisson_warp/poisson_warp.dart';
import 'test_dataset.dart';

void main(){
  test("Calculate the warp of the International Space Station", (){
    // 1. Setup Earth (The source of the gravity well)
    Body earth = Body(
      name: "Earth",
      mass: earthMass, // Uses the constant defined at the top
      position: Vector3.zero,
    );

    // 2. Setup ISS
    BigInt issDistanceFromEarthInMeters = BigInt.from(6791) * BigInt.from(1000);
    Body internationalSpaceStation = Body(
      name: "International Space Station",
      mass: BigDec.fromBigInt(BigInt.from(419725)),
      position: Vector3(
        x: BigDec.fromBigInt(issDistanceFromEarthInMeters), 
        y: BigDec.fromBigInt(BigInt.zero), 
        z: BigDec.fromBigInt(BigInt.zero),
      ),
    );

    print("Time is x${calculateWarpInASystem(bodies: [earth], targetBody: internationalSpaceStation).calculateDeformationRatio().toString()} in the ISS relative to the Earth.");
  });

  test("Calculate by taking into account all of the bodies in the Solar system", (){

  });
  test("Calculate the period and direction of the orbit for each body in the solar system and the position after certain amount of time has elapsed.", (){
    
    //SolarYear timeInSol = SolarYear(elapsedYears: BigDec.fromString("0.5"));
    //Vector3 earthPosition = kinematicEarth.motion.getPositionAtTime(timeInSol.inSeconds());
    ////Print resulting position
    //print("Position after ${timeInSol.elapsedYears.toString()} Solar Year");
    //print("x: ${earthPosition.x.toString()}");
    //print("y: ${earthPosition.y.toString()}");
    //print("z: ${earthPosition.z.toString()}");
  });
  test("Simulate half a year of displacement", (){
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
  });
}