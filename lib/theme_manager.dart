import 'package:flutter/material.dart';

class ThemeManager {
  // 1. הורדנו את המילה 'const' כדי שנוכל לשנות את הערכים בזמן ריצה
  static Color accentColor = const Color(0xFFFF0000);
  static Color bgColor = const Color(0xFF0A0A0A);
  static Color panelColor = const Color(0xFF111111);
  static Color borderColor = Colors.white12;

  // 2. הטריגר שלנו (כמו Event בלינוקס) שמודיע ל-UI להתרנדר מחדש
  static final ValueNotifier<int> themeNotifier = ValueNotifier(0);

  // 3. הפונקציה שמשנה את הצבע ולוחצת על ההדק
  static void updateAccentColor(Color newColor) {
    accentColor = newColor;
    // משנים את הערך של הטריגר כדי שפלאטר תדע שצריך לצייר מחדש
    themeNotifier.value++;
  }

  // הסטיילים נשארים אותו דבר, רק השתמשנו ב-const במקומות הנכונים
  static TextStyle headerStyle = const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
    color: Colors.white,
  );

  static TextStyle infoStyle = const TextStyle(
    fontWeight: FontWeight.bold,
    fontStyle: FontStyle.italic,
  );
}
