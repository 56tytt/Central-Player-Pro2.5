import 'package:flutter/material.dart';
import '../theme_manager.dart';

class PlaylistWidget extends StatelessWidget {
  final List<String> songs;
  final int activeIndex;
  final Function(int) onSongSelected;
  final VoidCallback onAddFilesPressed;

  const PlaylistWidget({
    super.key,
    required this.songs,
    required this.activeIndex,
    required this.onSongSelected,
    required this.onAddFilesPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text("🎵 MY LIBRARY", style: ThemeManager.headerStyle),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              onPressed: onAddFilesPressed,
              icon: const Icon(Icons.add, size: 18),
              label:  Text("Add Files", style: ThemeManager.infoStyle),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // הרשימה עצמה
        Expanded(
          child: ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              bool isActive = index == activeIndex;
              return InkWell(
                onTap: () => onSongSelected(index),
                child: Container(
                  color: isActive
                      ? Colors.white.withOpacity(0.05)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 5,
                  ),
                  child: Row(
                    children: [
                      if (isActive)
                        const Icon(
                          Icons.play_arrow,
                          color: Colors.lightBlueAccent,
                          size: 20,
                        ),
                      if (!isActive) const SizedBox(width: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          songs[index],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                            color: isActive
                                ? Colors.lightBlueAccent
                                : Colors.white60,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
