import 'package:big_dec/big_dec.dart';

// Values based on NASA Planetary Fact Sheets
// Sun
BigDec sunMass = BigDec.fromString("1.989e30".replaceAll("e30", "000000000000000000000000000000"));

// Planets (Mass in kg, Distance from Sun in meters)
// Mercury
BigDec mercuryMass = BigDec.fromString("3.301e23".replaceAll("e23", "00000000000000000000000"));
BigDec mercuryDist = BigDec.fromString("57900000000");

// Venus
BigDec venusMass = BigDec.fromString("4.867e24".replaceAll("e24", "000000000000000000000000"));
BigDec venusDist = BigDec.fromString("108200000000");

// Earth
BigDec earthMassVal = BigDec.fromString("5.972e24".replaceAll("e24", "000000000000000000000000"));
BigDec earthDist = BigDec.fromString("149600000000");

// Mars
BigDec marsMass = BigDec.fromString("6.417e23".replaceAll("e23", "00000000000000000000000"));
BigDec marsDist = BigDec.fromString("227900000000");

// Jupiter
BigDec jupiterMass = BigDec.fromString("1.898e27".replaceAll("e27", "000000000000000000000000000"));
BigDec jupiterDist = BigDec.fromString("778600000000");

// Saturn
BigDec saturnMass = BigDec.fromString("5.683e26".replaceAll("e26", "00000000000000000000000000"));
BigDec saturnDist = BigDec.fromString("1433500000000");

// Uranus
BigDec uranusMass = BigDec.fromString("8.681e25".replaceAll("e25", "0000000000000000000000000"));
BigDec uranusDist = BigDec.fromString("2872500000000");

// Neptune
BigDec neptuneMass = BigDec.fromString("1.024e26".replaceAll("e26", "00000000000000000000000000"));
BigDec neptuneDist = BigDec.fromString("4495100000000");