import 'package:big_dec/big_dec.dart';

class Vector3 {
  Vector3({required this.x, required this.y, required this.z, int decimalPlaces = 200}) {
    x.setDecimalPrecision(decimalPlaces);
    y.setDecimalPrecision(decimalPlaces);
    z.setDecimalPrecision(decimalPlaces);
  }
  
  BigDec x, y, z;

  static Vector3 zero({int decimalPlaces = 200}) => Vector3(
    x: BigDec.fromString("0"),
    y: BigDec.fromString("0"),
    z: BigDec.fromString("0"),
    decimalPlaces: decimalPlaces,
  );

  BigDec magnitude({int decimalPlaces = 200}) {
    final mag = (x.multiply(x).add(y.multiply(y)).add(z.multiply(z))).sqrt();
    return mag..setDecimalPrecision(decimalPlaces);
  }

  Vector3 subtract(Vector3 other, {int decimalPlaces = 200}) => Vector3(
    x: x.subtract(other.x), 
    y: y.subtract(other.y), 
    z: z.subtract(other.z),
    decimalPlaces: decimalPlaces,
  );
}

class Body {
  final String name;
  final BigDec gm;
  Vector3 position;
  Vector3 velocity;

  Body({
    required this.name, 
    required this.gm, 
    required this.position, 
    required this.velocity,
    int decimalPlaces = 200,
  }) {
    gm.setDecimalPrecision(decimalPlaces);
  }
}

class Antikythera {
  List<Body> _bodies;
  Antikythera({required List<Body> bodies}) : _bodies = bodies;

  BigDec _bd(String val, int dp) => BigDec.fromString(val)..setDecimalPrecision(dp);

  /// Pure BigDec Sine using Taylor Series
  BigDec _sinBD(BigDec x, int dp) {
    BigDec res = BigDec.fromString("0")..setDecimalPrecision(dp);
    BigDec term = x;
    BigDec xSq = x.multiply(x);
    for (int i = 1; i < 20; i++) {
      res = res.add(term);
      term = term.multiply(xSq).multiply(_bd("-1", dp)).divide(_bd("${(2 * i) * (2 * i + 1)}", dp));
    }
    return res;
  }

  /// Pure BigDec Cosine using Taylor Series
  BigDec _cosBD(BigDec x, int dp) {
    BigDec res = BigDec.fromString("0")..setDecimalPrecision(dp);
    BigDec term = _bd("1", dp);
    BigDec xSq = x.multiply(x);
    for (int i = 1; i < 20; i++) {
      res = res.add(term);
      term = term.multiply(xSq).multiply(_bd("-1", dp)).divide(_bd("${(2 * i - 1) * (2 * i)}", dp));
    }
    return res;
  }

  /// Calculates orbital positions in the Ecliptic Frame.
  void simulateEcliptic({required BigDec durationSeconds, int decimalPlaces = 200}) {
    final j2000 = _bd("946728000", decimalPlaces);
    final century = _bd("3155760000", decimalPlaces);
    BigDec tCenturies = durationSeconds.subtract(j2000).divide(century);

    for (int i = 0; i < _bodies.length; i++) {
      if (_bodies[i].name == "Sun") continue;
      final elements = _getKeplerianElements(_bodies[i].name, tCenturies, decimalPlaces);
      _bodies[i].position = _calculatePositionFromElements(elements, decimalPlaces);
    }
  }

  /// Calculates orbital positions and automatically transforms them to the 
  /// Equatorial Frame (J2000) to match NASA Horizons vector data.
  void simulateEquatorialFrame({required BigDec durationSeconds, int decimalPlaces = 200}) {
    simulateEcliptic(durationSeconds: durationSeconds, decimalPlaces: decimalPlaces);
    rotateToEquatorialFrame(decimalPlaces: decimalPlaces);
  }

  Map<String, BigDec> _getKeplerianElements(String name, BigDec T, int dp) {
    final Map<String, List<String>> table = {
      "Mercury": ["0.38709893", "0.00000066", "0.20563069", "0.00002523", "7.00487", "0.00000", "252.25084", "149472.67411", "77.45645", "0.16213", "48.33167", "1.18640"],
      "Venus":   ["0.72333199", "0.00000092", "0.00677323", "-0.00004938", "3.39471", "-0.00004", "181.97973", "58517.81538", "131.53298", "0.00201", "76.68069", "-0.27769"],
      "Earth":   ["1.00000011", "-0.00000005", "0.01671022", "-0.00003804", "0.00005", "-0.01300", "100.46435", "35999.37242", "102.94719", "0.32225", "0.0", "0.0"],
      "Mars":    ["1.52366231", "-0.00007221", "0.09341233", "0.00011902", "1.85061", "-0.00067", "355.45332", "19140.30268", "336.04084", "0.44403", "49.57854", "-1.11323"],
    };
    final data = table[name] ?? table["Earth"]!;
    return {
      'a': _bd(data[0], dp).add(_bd(data[1], dp).multiply(T)),
      'e': _bd(data[2], dp).add(_bd(data[3], dp).multiply(T)),
      'I': _bd(data[4], dp).add(_bd(data[5], dp).multiply(T)),
      'L': _bd(data[6], dp).add(_bd(data[7], dp).multiply(T)),
      'w': _bd(data[8], dp).add(_bd(data[9], dp).multiply(T)),
      'node': _bd(data[10], dp).add(_bd(data[11], dp).multiply(T)),
    };
  }

  Vector3 _calculatePositionFromElements(Map<String, BigDec> el, int dp) {
    final au = _bd("149597870700", dp);
    final d2r = _bd("0.017453292519943295", dp);
    final one = _bd("1", dp);

    BigDec aMeters = el['a']!.multiply(au);
    BigDec e = el['e']!;
    BigDec M = el['L']!.subtract(el['w']!).multiply(d2r);

    BigDec currentE = M;
    for (int i = 0; i < 15; i++) {
      BigDec sinE = _sinBD(currentE, dp);
      BigDec cosE = _cosBD(currentE, dp);
      BigDec numerator = currentE.subtract(e.multiply(sinE)).subtract(M);
      BigDec denominator = one.subtract(e.multiply(cosE));
      currentE = currentE.subtract(numerator.divide(denominator));
    }

    BigDec cosE = _cosBD(currentE, dp);
    BigDec sinE = _sinBD(currentE, dp);
    BigDec xP = aMeters.multiply(cosE.subtract(e));
    BigDec yP = aMeters.multiply(one.subtract(e.multiply(e)).sqrt()).multiply(sinE);

    BigDec nodeR = el['node']!.multiply(d2r);
    BigDec iR = el['I']!.multiply(d2r);
    BigDec argR = el['w']!.subtract(el['node']!).multiply(d2r);

    BigDec cosN = _cosBD(nodeR, dp); BigDec sinN = _sinBD(nodeR, dp);
    BigDec cosI = _cosBD(iR, dp); BigDec sinI = _sinBD(iR, dp);
    BigDec cosW = _cosBD(argR, dp); BigDec sinW = _sinBD(argR, dp);

    BigDec x = (cosN.multiply(cosW).subtract(sinN.multiply(sinW).multiply(cosI))).multiply(xP)
               .add((cosN.multiply(sinW).multiply(_bd("-1", dp)).subtract(sinN.multiply(cosW).multiply(cosI))).multiply(yP));
    BigDec y = (sinN.multiply(cosW).add(cosN.multiply(sinW).multiply(cosI))).multiply(xP)
               .add((sinN.multiply(sinW).multiply(_bd("-1", dp)).add(cosN.multiply(cosW).multiply(cosI))).multiply(yP));
    BigDec z = (sinW.multiply(sinI)).multiply(xP).add((cosW.multiply(sinI)).multiply(yP));

    return Vector3(x: x, y: y, z: z, decimalPlaces: dp);
  }

  void recenterRelativeToReference(Body reference, {int decimalPlaces = 200}) {
    final target = _bodies.cast<Body?>().firstWhere((b) => b?.name == reference.name, orElse: () => null);
    if (target == null) return;
    final offset = target.position.subtract(reference.position, decimalPlaces: decimalPlaces);
    for (int i = 0; i < _bodies.length; i++) {
      _bodies[i].position = _bodies[i].position.subtract(offset, decimalPlaces: decimalPlaces);
    }
  }

  Body? getBodyByName(String name) => _bodies.cast<Body?>().firstWhere((b) => b?.name == name, orElse: () => null);

  /// Rotates the entire system from the Ecliptic Frame to the Equatorial Frame
  /// to match NASA Horizons vector data (J2000).
  void rotateToEquatorialFrame({int decimalPlaces = 200}) {
    final BigDec d2r = _bd("0.017453292519943295", decimalPlaces);
    final BigDec obliquity = _bd("23.4392911", decimalPlaces).multiply(d2r);
    
    final BigDec cosObl = _cosBD(obliquity, decimalPlaces);
    final BigDec sinObl = _sinBD(obliquity, decimalPlaces);

    for (int i = 0; i < _bodies.length; i++) {
      final pos = _bodies[i].position;
      final vel = _bodies[i].velocity;

      final BigDec newPosY = pos.y.multiply(cosObl).subtract(pos.z.multiply(sinObl));
      final BigDec newPosZ = pos.y.multiply(sinObl).add(pos.z.multiply(cosObl));
      
      _bodies[i].position = Vector3(
        x: pos.x, 
        y: newPosY, 
        z: newPosZ, 
        decimalPlaces: decimalPlaces
      );

      final BigDec newVelY = vel.y.multiply(cosObl).subtract(vel.z.multiply(sinObl));
      final BigDec newVelZ = vel.y.multiply(sinObl).add(vel.z.multiply(cosObl));
      
      _bodies[i].velocity = Vector3(
        x: vel.x, 
        y: newVelY, 
        z: newVelZ, 
        decimalPlaces: decimalPlaces
      );
    }
  }

  /// Shifts all bodies so that the center of mass (Barycenter) is at (0,0,0).
  void recenterBarycenter({int decimalPlaces = 200}) {
    Vector3 totalWeightedPos = Vector3.zero(decimalPlaces: decimalPlaces);
    BigDec totalMass = _bd("0", decimalPlaces);

    for (var body in _bodies) {
      totalWeightedPos.x = totalWeightedPos.x.add(body.position.x.multiply(body.gm));
      totalWeightedPos.y = totalWeightedPos.y.add(body.position.y.multiply(body.gm));
      totalWeightedPos.z = totalWeightedPos.z.add(body.position.z.multiply(body.gm));
      totalMass = totalMass.add(body.gm);
    }

    Vector3 barycenter = Vector3(
      x: totalWeightedPos.x.divide(totalMass),
      y: totalWeightedPos.y.divide(totalMass),
      z: totalWeightedPos.z.divide(totalMass),
      decimalPlaces: decimalPlaces,
    );

    for (int i = 0; i < _bodies.length; i++) {
      _bodies[i].position = _bodies[i].position.subtract(barycenter, decimalPlaces: decimalPlaces);
    }
  }
}