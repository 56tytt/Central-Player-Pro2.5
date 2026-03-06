import 'package:flutter/material.dart';
import '../theme_manager.dart';

class PlayerControlsWidget extends StatelessWidget {
  final String currentSongTitle;
  final bool isPlaying;
  final double currentPosition;
  final double totalDuration;
  final VoidCallback onPlayPauseToggled;
  final Function(double) onSeek;

  const PlayerControlsWidget({
    super.key,
    required this.currentSongTitle,
    required this.isPlaying,
    required this.currentPosition,
    required this.totalDuration,
    required this.onPlayPauseToggled,
    required this.onSeek,
  });

  String formatTime(double seconds) {
    int mins = (seconds / 60).floor();
    int secs = (seconds % 60).floor();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildCircleButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 4),
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // כפתורים ושם השיר
        Row(
          children: [
            _buildCircleButton(
              Icons.arrow_back,
              const Color(0xFF00B050),
              () {},
            ), // Back
            const SizedBox(width: 15),
            _buildCircleButton(
              isPlaying ? Icons.pause : Icons.play_arrow,
              ThemeManager.accentColor,
              onPlayPauseToggled,
            ),
            const SizedBox(width: 15),
            _buildCircleButton(
              Icons.arrow_forward,
              const Color(0xFF800000),
              () {},
            ), // Next
            const SizedBox(width: 30),
            Expanded(
              child: Text(
                currentSongTitle,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // פס התקדמות (Slider)
        Row(
          children: [
            Text(
              formatTime(currentPosition),
              style:  TextStyle(
                color: ThemeManager.accentColor,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: ThemeManager.accentColor,
                  inactiveTrackColor: Colors.white10,
                  thumbColor: Colors.white,
                  trackHeight: 6.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8.0,
                    elevation: 5,
                  ),
                ),
                child: Slider(
                  value: currentPosition,
                  max: totalDuration > 0 ? totalDuration : 1.0,
                  onChanged: onSeek,
                ),
              ),
            ),
            Text(
              formatTime(totalDuration),
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),

        // ספקטרום דמה
        SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(40, (index) {
              double height = isPlaying
                  ? (10 + (15 * (index % 5)) + (index == 20 ? 20 : 0))
                  : 4.0;
              return Container(
                width: 8,
                height: height > 40 ? 40 : height,
                decoration: BoxDecoration(
                  color: ThemeManager.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
