import 'package:big_dec/big_dec.dart';

class Vector3 {
  BigDec x, y, z;
  final int decimalPrecision;

  Vector3({
    required this.x,
    required this.y,
    required this.z,
    this.decimalPrecision = 200,
  }) {
    x.setDecimalPrecision(decimalPrecision);
    y.setDecimalPrecision(decimalPrecision);
    z.setDecimalPrecision(decimalPrecision);
  }

  BigDec magnitude() {
    //x^2 + y^2 + z^2 = magnitude^2
    final BigDec xsq = (x * x)..setDecimalPrecision(decimalPrecision);
    final BigDec ysq = (y * y)..setDecimalPrecision(decimalPrecision);
    final BigDec zsq = (z * z)..setDecimalPrecision(decimalPrecision);
    final BigDec sum = (xsq + ysq + zsq)..setDecimalPrecision(decimalPrecision);
    return sum.sqrt()..setDecimalPrecision(decimalPrecision);
  }

  Vector3 add(Vector3 other) => Vector3(
    x: (x + other.x)..setDecimalPrecision(decimalPrecision),
    y: (y + other.y)..setDecimalPrecision(decimalPrecision),
    z: (z + other.z)..setDecimalPrecision(decimalPrecision),
    decimalPrecision: decimalPrecision,
  );

  Vector3 subtract(Vector3 other) => Vector3(
    x: (x - other.x)..setDecimalPrecision(decimalPrecision),
    y: (y - other.y)..setDecimalPrecision(decimalPrecision),
    z: (z - other.z)..setDecimalPrecision(decimalPrecision),
    decimalPrecision: decimalPrecision,
  );
  Vector3 divide(Vector3 other) => Vector3(
    x: (x / other.x)..setDecimalPrecision(decimalPrecision),
    y: (y / other.y)..setDecimalPrecision(decimalPrecision),
    z: (z / other.z)..setDecimalPrecision(decimalPrecision),
    decimalPrecision: decimalPrecision,
  );
  Vector3 multiply(Vector3 other) => Vector3(
    x: (x * other.x)..setDecimalPrecision(decimalPrecision),
    y: (y * other.y)..setDecimalPrecision(decimalPrecision),
    z: (z * other.z)..setDecimalPrecision(decimalPrecision),
    decimalPrecision: decimalPrecision,
  );
}

class Body {
  Body({
    required this.name,
    required this.gm,
    required this.position,
    required this.velocity,
  });
  final String name;
  final BigDec gm; //GM
  Vector3 position;
  Vector3 velocity;
}

class Antikythera {
  List<Body> _bodies;
  final int decimalPrecision;

  Antikythera({
    required List<Body> bodies,
    this.decimalPrecision = 200,
  }) : _bodies = bodies;

  void simulateMotion({
    required BigDec durationInSeconds,
    required Function(BigInt stepsSimulated) onStep,
    required BigInt steps,
  }) {
    //Make simulations using stepped simplectic euler formula
    BigDec deltaTime = durationInSeconds / BigDec.fromBigInt(steps);
    List<Body> temporaryList = [];
    for(BigInt step = BigInt.zero; step < steps; step += BigInt.one){
      onStep(step);
      for(int i = 0; i < _bodies.length; i++){
        Body body1 = _bodies[i];
        Vector3 gravitationalAcceleration = Vector3(x: BigDec.zero, y: BigDec.zero, z: BigDec.zero);
        for(int j = 0; j < _bodies.length; j++){
          if(i != j){
            Body body2 = _bodies[j];
            gravitationalAcceleration = gravitationalAcceleration.add(calculateGravitationalAcceleration(body1: body1, body2: body2));
          }
        }
        Vector3 stepAcceleration = gravitationalAcceleration.multiply(Vector3(x: deltaTime, y: deltaTime, z: deltaTime));
        Vector3 velocity = body1.velocity.add(stepAcceleration);
        Vector3 position = body1.position.add(velocity.multiply(Vector3(x: deltaTime, y: deltaTime, z: deltaTime)));
        temporaryList.add(Body(
          name: body1.name, 
          gm: body1.gm, 
          position: position, 
          velocity: velocity,
        ));
      }
      _bodies = temporaryList;
      temporaryList = [];
    }
  }

  // --------------------------------------------------------------------------
  // BARYCENTER
  // --------------------------------------------------------------------------
  Vector3 calculateBarycenter() {
    //Calculate the center of the system
    Vector3 barycenter = Vector3(x: BigDec.fromBigInt(BigInt.zero), y: BigDec.fromBigInt(BigInt.zero), z: BigDec.fromBigInt(BigInt.zero), decimalPrecision: decimalPrecision);
    if(bodies.isEmpty){
      return barycenter;
    }else if(bodies.length == 1){
      return bodies.first.position;
    }else{
      BigDec gmSum = BigDec.zero;
      Vector3 gmTimesPosition = barycenter;
      for(Body body in bodies){
        gmSum += body.gm;
        gmTimesPosition = gmTimesPosition.add(Vector3(x: body.gm, y: body.gm, z: body.gm).multiply(body.position));
      }
      barycenter = gmTimesPosition.divide(Vector3(x: gmSum, y: gmSum, z: gmSum));
      return barycenter;
    }
  }

  Vector3 calculateGravitationalAcceleration({
    required Body body1,
    required Body body2,
  }){
    //g = GM/r^2
    Vector3 displacement = body2.position.subtract(body1.position);
    BigDec r = displacement.magnitude();

    if(r == BigDec.zero){
      return Vector3(
        x: BigDec.fromBigInt(BigInt.zero),
        y: BigDec.fromBigInt(BigInt.zero),
        z: BigDec.fromBigInt(BigInt.zero),
        decimalPrecision: decimalPrecision,
      );
    }

    // Calculate r^3
    BigDec rCubed = (r * r * r)..setDecimalPrecision(decimalPrecision);

    // Calculate the common scalar force multiplier: GM / r^3
    BigDec scalarMultiplier = (body2.gm / rCubed)..setDecimalPrecision(decimalPrecision);

    // Multiply the directional components by the correct 3D scalar multiplier
    return Vector3(
      x: (displacement.x * scalarMultiplier)..setDecimalPrecision(decimalPrecision),
      y: (displacement.y * scalarMultiplier)..setDecimalPrecision(decimalPrecision),
      z: (displacement.z * scalarMultiplier)..setDecimalPrecision(decimalPrecision),
      decimalPrecision: decimalPrecision,
    );
  }

  Body getBodyByName(String name) {
    for (final body in _bodies) {
      if (body.name == name) return body;
    }
    throw StateError("Body '$name' not found in the list of bodies.");
  }

  List<Body> get bodies => _bodies;
}

class SolarYear {
  SolarYear({
    required this.earthYears,
    this.decimalPrecision = 200,
  }) {
    earthYears.setDecimalPrecision(decimalPrecision);
  }

  final BigDec earthYears;
  final int decimalPrecision;

  BigDec inSeconds() {
    BigDec oneYearInDays = BigDec.fromString("365.242").setDecimalPrecision(decimalPrecision);
    BigDec oneDayInSeconds = BigDec.fromString("86400").setDecimalPrecision(decimalPrecision);
    return oneYearInDays * oneDayInSeconds * earthYears;
  }
}
