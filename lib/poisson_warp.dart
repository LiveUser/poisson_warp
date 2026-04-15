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
    final BigDec xsq = (x * x)..setDecimalPrecision(decimalPrecision);
    final BigDec ysq = (y * y)..setDecimalPrecision(decimalPrecision);
    final BigDec zsq = (z * z)..setDecimalPrecision(decimalPrecision);
    final BigDec sum = (xsq + ysq + zsq)..setDecimalPrecision(decimalPrecision);
    final BigDec mag = sum.sqrt()..setDecimalPrecision(decimalPrecision);
    return mag;
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

  Vector3 scale(BigDec scalar) {
    scalar.setDecimalPrecision(decimalPrecision);
    return Vector3(
      x: (x * scalar)..setDecimalPrecision(decimalPrecision),
      y: (y * scalar)..setDecimalPrecision(decimalPrecision),
      z: (z * scalar)..setDecimalPrecision(decimalPrecision),
      decimalPrecision: decimalPrecision,
    );
  }
}

class Body {
  final String name;
  final BigDec gm; // GM = G * M
  BigDec radius;
  BigDec axialVelocityInDegreesPerSecond;
  Vector3 position;
  Vector3 velocity;

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
  final int decimalPrecision;

  Antikythera({
    required List<Body> bodies,
    this.decimalPrecision = 200,
  }) : _bodies = bodies;

  // --------------------------------------------------------------------------
  // CORE SYMPLECTIC EULER INTEGRATOR
  // --------------------------------------------------------------------------
  void simulateMotion({
    required BigDec durationInSeconds,
    required Function(BigInt stepsSimulated) onStep,
    required BigInt steps,
  }) {
    durationInSeconds.setDecimalPrecision(decimalPrecision);
    final BigDec stepsDec =
        BigDec.fromBigInt(steps)..setDecimalPrecision(decimalPrecision);
    final BigDec dt = (durationInSeconds / stepsDec)
      ..setDecimalPrecision(decimalPrecision);

    for (BigInt i = BigInt.zero; i < steps; i = i + BigInt.one) {
      // 1. Accelerations from current positions
      final List<Vector3> accs =
          _bodies.map((b) => _calculateAcc(b)).toList();

      // 2. Symplectic step: update velocities first
      for (int j = 0; j < _bodies.length; j++) {
        final Vector3 dv = accs[j].scale(dt);
        _bodies[j].velocity = _bodies[j].velocity.add(dv);
      }

      // 3. Then update positions using new velocities
      for (int j = 0; j < _bodies.length; j++) {
        final Vector3 dp = _bodies[j].velocity.scale(dt);
        _bodies[j].position = _bodies[j].position.add(dp);
      }

      onStep(i + BigInt.one);
    }
  }

  // --------------------------------------------------------------------------
  // WARP-BASED ACCELERATION MODEL (mass + spin deepen the "hole")
  // --------------------------------------------------------------------------
  Vector3 _calculateAcc(Body target) {
    // Gravitational constant (SI)
    final BigDec G =
        BigDec.fromString("6.67430e-11")..setDecimalPrecision(decimalPrecision);

    // Tunable warp constant: how strongly spin amplifies attraction
    final BigDec warpK =
        BigDec.fromString("1e-30")..setDecimalPrecision(decimalPrecision);

    Vector3 totalAcc = Vector3(
      x: BigDec.zero..setDecimalPrecision(decimalPrecision),
      y: BigDec.zero..setDecimalPrecision(decimalPrecision),
      z: BigDec.zero..setDecimalPrecision(decimalPrecision),
      decimalPrecision: decimalPrecision,
    );

    for (final source in _bodies) {
      if (identical(source, target)) continue;

      // Vector from target to source
      final Vector3 rVec = Vector3(
        x: source.position.x - target.position.x,
        y: source.position.y - target.position.y,
        z: source.position.z - target.position.z,
        decimalPrecision: decimalPrecision,
      );
      final BigDec rMag = rVec.magnitude();

      // Avoid singularity at extremely small distances
      if (rMag
              .compareTo(BigDec.fromString("0.0001")
                ..setDecimalPrecision(decimalPrecision)) <=
          0) {
        continue;
      }

      // --- 1. Newtonian gravity ---
      final BigDec rSq = (rMag * rMag)..setDecimalPrecision(decimalPrecision);
      final BigDec rCubed = (rSq * rMag)..setDecimalPrecision(decimalPrecision);

      // a_Newton = GM / r^3 * rVec
      final BigDec scalarNewton =
          (source.gm / rCubed)..setDecimalPrecision(decimalPrecision);
      final Vector3 newtonianAcc = rVec.scale(scalarNewton);

      // --- 2. Warp: mass + axial velocity deepen the "hole" ---
      // Mass from GM: M = GM / G
      final BigDec mass =
          (source.gm / G)..setDecimalPrecision(decimalPrecision);

      // Angular speed in rad/s: omega = deg/s * pi/180
      final BigDec piOver180 = BigDec.fromString("0.017453292519943295")
        ..setDecimalPrecision(decimalPrecision);
      final BigDec omegaRadPerSec =
          (source.axialVelocityInDegreesPerSecond * piOver180)
            ..setDecimalPrecision(decimalPrecision);

      // |omega|
      final BigDec absOmega = omegaRadPerSec.compareTo(BigDec.zero) < 0
          ? ((-omegaRadPerSec)..setDecimalPrecision(decimalPrecision))
          : omegaRadPerSec..setDecimalPrecision(decimalPrecision);

      // Warp strength for this body: W_body = warpK * M * |omega|
      final BigDec warpBody =
          (warpK * mass * absOmega)..setDecimalPrecision(decimalPrecision);

      // Distance falloff: local effect near the body
      // f(r) = R / r
      final BigDec falloff =
          (source.radius / rMag)..setDecimalPrecision(decimalPrecision);

      // Warp factor on attraction: F_warp = 1 + W_body * f(r)
      final BigDec warpContribution =
          (warpBody * falloff)..setDecimalPrecision(decimalPrecision);
      final BigDec one = BigDec.one..setDecimalPrecision(decimalPrecision);
      BigDec warpFactor =
          (one + warpContribution)..setDecimalPrecision(decimalPrecision);

      // Prevent negative warp factor in extreme cases
      if (warpFactor.compareTo(BigDec.zero) < 0) {
        warpFactor = one;
      }

      // Final acceleration from this source:
      // a_total = F_warp * a_Newton
      final Vector3 warpedAcc = newtonianAcc.scale(warpFactor);

      totalAcc = totalAcc.add(warpedAcc);
    }

    return totalAcc;
  }

  // --------------------------------------------------------------------------
  // BARYCENTER
  // --------------------------------------------------------------------------
  Vector3 calculateBarycenter() {
    Vector3 weightedPositions = Vector3(
      x: BigDec.zero..setDecimalPrecision(decimalPrecision),
      y: BigDec.zero..setDecimalPrecision(decimalPrecision),
      z: BigDec.zero..setDecimalPrecision(decimalPrecision),
      decimalPrecision: decimalPrecision,
    );
    BigDec totalGM = BigDec.zero..setDecimalPrecision(decimalPrecision);

    for (final body in _bodies) {
      final Vector3 weighted = weightedPositions.scale(body.gm);
      weightedPositions = weightedPositions.add(weighted);
      totalGM = (totalGM + body.gm)..setDecimalPrecision(decimalPrecision);
    }

    return Vector3(
      x: (weightedPositions.x / totalGM)..setDecimalPrecision(decimalPrecision),
      y: (weightedPositions.y / totalGM)..setDecimalPrecision(decimalPrecision),
      z: (weightedPositions.z / totalGM)..setDecimalPrecision(decimalPrecision),
      decimalPrecision: decimalPrecision,
    );
  }

  Body? getBodyByName(String name) =>
      _bodies.where((b) => b.name == name).cast<Body?>().firstWhere(
            (b) => b?.name == name,
            orElse: () => null,
          );

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
    final BigDec oneYearInSeconds =
        BigDec.fromString("31556925.216")..setDecimalPrecision(decimalPrecision);
    final BigDec seconds =
        (earthYears * oneYearInSeconds)..setDecimalPrecision(decimalPrecision);
    return seconds;
  }
}
