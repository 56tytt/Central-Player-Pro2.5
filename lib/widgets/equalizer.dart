import 'package:flutter/material.dart';
import '../theme_manager.dart';

class EqualizerWidget extends StatelessWidget {
  final List<double> eqValues;
  final double masterVolume;
  final String currentPreset;
  final Function(int, double) onEqChanged;
  final Function(double) onVolumeChanged;
  final Function(String) onPresetChanged; // פונקציה חדשה לשינוי מצב!

  const EqualizerWidget({
    super.key,
    required this.eqValues,
    required this.masterVolume,
    required this.currentPreset,
    required this.onEqChanged,
    required this.onVolumeChanged,
    required this.onPresetChanged,
  });

  static const List<String> bands = [
    '29',
    '59',
    '119',
    '237',
    '474',
    '947',
    '1.8k',
    '3.7k',
    '7.5k',
    '15k',
  ];
  static const List<String> presets = [
    'Flat',
    'Rock',
    'Jazz',
    'Classical',
    'Pop',
    'Bass Boost',
    'Custom',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeManager.panelColor,
        border: Border.all(color: ThemeManager.borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                  Text("🎚 EQ & MASTER", style: ThemeManager.headerStyle),
              // תפריט נפתח לבחירת מצבי אקולייזר!
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentPreset,
                    dropdownColor: ThemeManager.panelColor,
                    style: ThemeManager.infoStyle.copyWith(color: Colors.white),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white54,
                    ),
                    items: presets.map((String preset) {
                      return DropdownMenuItem<String>(
                        value: preset,
                        child: Text(preset),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) onPresetChanged(newValue);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...List.generate(
                10,
                (index) => _buildVerticalSlider(
                  context,
                  bands[index],
                  eqValues[index],
                  Theme.of(context).primaryColor,
                  (v) => onEqChanged(index, v),
                ),
              ),
              _buildVerticalSlider(
                context,
                "VOL",
                masterVolume,
                Colors.grey,
                onVolumeChanged,
                isVolume: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalSlider(
    BuildContext context,
    String label,
    double value,
    Color activeColor,
    ValueChanged<double> onChanged, {
    bool isVolume = false,
  }) {
    return Column(
      children: [
        SizedBox(
          height: 125,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: activeColor,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.grey[300],
                trackHeight: 8.0,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6.0,
                ),
              ),
              child: Slider(
                value: value,
                // ווליום הוא מ-0 עד 1, אבל ה-EQ הוא ממינוס 24 עד פלוס 12 (dB)!
                min: isVolume ? 0.0 : -24.0,
                max: isVolume ? 1.0 : 12.0,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isVolume ? Colors.white : Colors.cyanAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}





class SpectrumVisualizer extends StatelessWidget {
  final List<double> fftData; // רשימת התדרים (למשל 10 או 20 עמודות)
  final Color color; // הצבע של ה-Theme שלנו!

  const SpectrumVisualizer({super.key, required this.fftData, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 80), // גובה האקולייזר במסך
      painter: _SpectrumPainter(fftData, color),
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> fftData;
  final Color color;

  _SpectrumPainter(this.fftData, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (fftData.isEmpty) return;

    final paint = Paint()
    ..color = color
    ..style = PaintingStyle.fill;

    // מחשבים כמה רוחב יש לכל עמודה לפי כמות התדרים שנעביר
    final barWidth = size.width / fftData.length;
    final spacing = barWidth * 0.2; // 20% רווח בין עמודה לעמודה
    final actualBarWidth = barWidth - spacing;

    for (int i = 0; i < fftData.length; i++) {
      // מוודאים שהגובה לא עובר את ה-1.0 כדי שלא נצייר מחוץ למסך
      final normalizedValue = fftData[i].clamp(0.0, 1.0);
      final barHeight = size.height * normalizedValue;

      final x = i * barWidth + (spacing / 2);
      final y = size.height - barHeight;

      // מציירים מלבן מעוגל יפהפה
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        const Radius.circular(4),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return true; // אנחנו אומרים לפלאטר: "תמיד תצייר מחדש כשמגיעים נתונים!"
  }
}
