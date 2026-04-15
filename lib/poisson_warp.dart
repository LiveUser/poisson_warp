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
    return sum.sqrt()..setDecimalPrecision(decimalPrecision);
  }

  BigDec magnitudeSquared() {
    final BigDec xsq = (x * x)..setDecimalPrecision(decimalPrecision);
    final BigDec ysq = (y * y)..setDecimalPrecision(decimalPrecision);
    final BigDec zsq = (z * z)..setDecimalPrecision(decimalPrecision);
    return (xsq + ysq + zsq)..setDecimalPrecision(decimalPrecision);
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
  final BigDec gm; // G * M
  Vector3 position;
  Vector3 velocity;

  /// Rotation of the body around its own axis, in degrees per second.
  /// This is NOT orbital angular velocity.
  BigDec axialVelocityInDegreesPerSecond;

  Body({
    required this.name,
    required this.gm,
    required this.position,
    required this.velocity,
    BigDec? axialVelocityInDegreesPerSecond,
  }) : axialVelocityInDegreesPerSecond =
            axialVelocityInDegreesPerSecond ??
            BigDec.fromString("0.004178074"); // ≈ Earth's axial rotation in deg/s
}

class Antikythera {
  final List<Body> _bodies;
  final int decimalPrecision;

  /// Optional: central mass used for GR-like geometry (e.g. the Sun).
  final Body? centralBody;

  /// Optional: reference body for "Earth-like" tick (e.g. Earth).
  final Body? earthReferenceBody;

  /// Speed of light in m/s.
  static final BigDec speedOfLightMetersPerSecond =
      BigDec.fromString("299792458");

  /// Dimensionless scale factor for warp radius (kept for compatibility, not used in core GR).
  static final BigDec warpRadiusScaleFactorK_R = BigDec.fromString("10.0");

  /// Dimensionless moment of inertia factor (kept for compatibility).
  static final BigDec momentOfInertiaFactorK_I = BigDec.fromString("0.4");

  /// Dimensionless tuning factor for frame-dragging (kept for compatibility).
  static final BigDec frameDraggingFactorK_FD =
      BigDec.fromString("0.0000001");

  /// π for rad/deg conversion.
  static final BigDec pi = BigDec.fromString("3.14159265358979323846");

  Antikythera({
    required List<Body> bodies,
    this.decimalPrecision = 200,
    this.centralBody,
    this.earthReferenceBody,
  }) : _bodies = bodies;

  // --------------------------------------------------------------------------
  // SYMPLECTIC EULER WITH RELATIVISTIC TICK FACTOR (WEAK-FIELD GR + SR)
  //
  // We keep Newtonian N-body gravity for dynamics, and use a weak-field
  // relativistic proper-time factor for each body:
  //
  //   Φ(r) = -GM / r
  //   v^2 = |v|^2
  //   dτ/dt ≈ sqrt(1 + 2Φ/c^2 - v^2/c^2)
  //
  // Tick factor is normalized to an Earth-like reference body:
  //
  //   tick(body) = (dτ/dt)_body / (dτ/dt)_earthRef
  //
  // This keeps the symplectic Euler integrator but makes the tick factor
  // physically grounded instead of ad-hoc.
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
      // 1. Compute Newtonian accelerations for all bodies.
      final List<Vector3> accs =
          _bodies.map((b) => _calculateAcc(b)).toList();

      // 2. Compute relativistic tick factors for all bodies.
      final List<BigDec> tickFactors =
          _bodies.map((b) => computeTickFactorForBody(b)).toList();

      // 3. Update velocities using symplectic Euler with local proper-time dt.
      for (int j = 0; j < _bodies.length; j++) {
        final BigDec localDt =
            (dt * tickFactors[j])..setDecimalPrecision(decimalPrecision);
        _bodies[j].velocity =
            _bodies[j].velocity.add(accs[j].scale(localDt));
      }

      // 4. Update positions using updated velocities and same local proper-time dt.
      for (int j = 0; j < _bodies.length; j++) {
        final BigDec localDt =
            (dt * tickFactors[j])..setDecimalPrecision(decimalPrecision);
        _bodies[j].position =
            _bodies[j].position.add(_bodies[j].velocity.scale(localDt));
      }

      onStep(i + BigInt.one);
    }
  }

  // --------------------------------------------------------------------------
  // PURE NEWTONIAN ACCELERATION (N-BODY)
  // --------------------------------------------------------------------------
  Vector3 _calculateAcc(Body target) {
    final int p = decimalPrecision;

    Vector3 totalAcc = Vector3(
      x: BigDec.zero..setDecimalPrecision(p),
      y: BigDec.zero..setDecimalPrecision(p),
      z: BigDec.zero..setDecimalPrecision(p),
      decimalPrecision: p,
    );

    for (final source in _bodies) {
      if (identical(source, target)) continue;

      final Vector3 rVec = Vector3(
        x: source.position.x - target.position.x,
        y: source.position.y - target.position.y,
        z: source.position.z - target.position.z,
        decimalPrecision: p,
      );

      final BigDec rMag = rVec.magnitude();

      // Avoid singularity / extremely close encounters.
      if (rMag.compareTo(BigDec.fromString("0.0001")..setDecimalPrecision(p)) <=
          0) {
        continue;
      }

      final BigDec rSq = (rMag * rMag)..setDecimalPrecision(p);
      final BigDec rCubed = (rSq * rMag)..setDecimalPrecision(p);

      final BigDec scalarNewton =
          (source.gm / rCubed)..setDecimalPrecision(p);

      final Vector3 newtonianAcc = rVec.scale(scalarNewton);

      totalAcc = totalAcc.add(newtonianAcc);
    }

    return totalAcc;
  }

  // --------------------------------------------------------------------------
  // RELATIVISTIC TICK FACTOR (WEAK-FIELD GR + SPECIAL RELATIVITY)
  //
  // We approximate proper time for each body using:
  //
  //   Φ(r) = -GM_central / r
  //   v^2 = |v|^2
  //   dτ/dt ≈ sqrt(1 + 2Φ/c^2 - v^2/c^2)
  //
  // Then normalize to an Earth-like reference body:
  //
  //   tick(body) = (dτ/dt)_body / (dτ/dt)_earthRef
  //
  // If no earthReferenceBody is provided, we fall back to the central body
  // as the reference.
  // --------------------------------------------------------------------------
  BigDec computeTickFactorForBody(Body body) {
    final int p = decimalPrecision;

    final Body central = centralBody ?? _bodies.first;
    final Body earthRef = earthReferenceBody ?? central;

    final BigDec c = speedOfLightMetersPerSecond..setDecimalPrecision(p);
    final BigDec cSq = (c * c)..setDecimalPrecision(p);
    final BigDec two = BigDec.fromInt(2)..setDecimalPrecision(p);
    final BigDec one = BigDec.one..setDecimalPrecision(p);

    BigDec _radiusFromCentral(Body b) {
      final Vector3 rVec = Vector3(
        x: b.position.x - central.position.x,
        y: b.position.y - central.position.y,
        z: b.position.z - central.position.z,
        decimalPrecision: p,
      );
      final BigDec r = rVec.magnitude()..setDecimalPrecision(p);
      if (r.compareTo(BigDec.zero..setDecimalPrecision(p)) <= 0) {
        return BigDec.fromString("1.0")..setDecimalPrecision(p);
      }
      return r;
    }

    BigDec _vSquared(Body b) {
      return b.velocity.magnitudeSquared()..setDecimalPrecision(p);
    }

    BigDec _properTimeFactor(Body b) {
      final BigDec r = _radiusFromCentral(b);
      final BigDec vSq = _vSquared(b);

      // Gravitational potential Φ = -GM / r (central mass only).
      BigDec phi = (central.gm / r)..setDecimalPrecision(p);
      phi = (phi * BigDec.fromInt(-1)..setDecimalPrecision(p))
        ..setDecimalPrecision(p);

      // term = 1 + 2Φ/c^2 - v^2/c^2
      BigDec term = (two * phi)..setDecimalPrecision(p);
      term = (term / cSq)..setDecimalPrecision(p);

      BigDec vTerm = (vSq / cSq)..setDecimalPrecision(p);

      BigDec inside = (one + term)..setDecimalPrecision(p);
      inside = (inside - vTerm)..setDecimalPrecision(p);

      // Clamp to avoid negative due to numerical issues.
      final BigDec almostZero =
          BigDec.fromString("1e-30")..setDecimalPrecision(p);
      if (inside.compareTo(almostZero) < 0) {
        inside = almostZero;
      }

      return inside.sqrt()..setDecimalPrecision(p);
    }

    final BigDec tauDotBody = _properTimeFactor(body);
    final BigDec tauDotEarth = _properTimeFactor(earthRef);

    BigDec tick =
        (tauDotBody / tauDotEarth)..setDecimalPrecision(p);

    return tick;
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
      final Vector3 weighted = body.position.scale(body.gm);
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

  Body getBodyByName(String name) {
    for (final b in _bodies) {
      if (b.name == name) return b;
    }
    throw StateError("Body '$name' not found in simulation.");
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
    final BigDec oneYearInSeconds =
        BigDec.fromString("31556925.216")..setDecimalPrecision(decimalPrecision);
    return (earthYears * oneYearInSeconds)
      ..setDecimalPrecision(decimalPrecision);
  }
}
