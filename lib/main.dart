import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io'; // הוספנו את זה בשביל לסרוק תיקיות!
import 'package:file_picker/file_picker.dart';
import 'audio_engine.dart';
import 'theme_manager.dart';
import 'widgets/equalizer.dart';
import 'widgets/playlist.dart';
import 'widgets/player_controls.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:convert';
import 'dart:io';

class AudioTrack {
  final String title;
  final String path;
  AudioTrack({required this.title, required this.path});
}

void main() {
  runApp(
    // המאזין שלנו! כל פעם שהטריגר נלחץ, הוא בונה את הכל מחדש
    ValueListenableBuilder(
      valueListenable: ThemeManager.themeNotifier,
      builder: (context, _, __) {
        return const CentralPlayerApp();
      },
    ),
  );
}

class CentralPlayerApp extends StatefulWidget {
  const CentralPlayerApp({super.key});

  @override
  State<CentralPlayerApp> createState() => _CentralPlayerAppState();
}

// הפכנו את האפליקציה הראשית ל-Stateful כדי שבעתיד נוכל לעדכן פה את צבע ה-Theme והפונט לכל האפליקציה
class _CentralPlayerAppState extends State<CentralPlayerApp> {
  Color _currentThemeColor = ThemeManager.accentColor;
  String _currentFont = 'CustomRB'; // נשנה את זה בהמשך

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Central Player Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ThemeManager.bgColor,
        primaryColor: _currentThemeColor,
        fontFamily: 'CustomRB',
      ),
      home: CentralPlayerPro(
        themeColor: _currentThemeColor,
        onThemeChanged: (color) => setState(() => _currentThemeColor = color),
      ),
    );
  }
}

class CentralPlayerPro extends StatefulWidget {
  final Color themeColor;
  final ValueChanged<Color> onThemeChanged;

  const CentralPlayerPro({
    super.key,
    required this.themeColor,
    required this.onThemeChanged,
  });

  @override
  State<CentralPlayerPro> createState() => _CentralPlayerProState();
}

class _CentralPlayerProState extends State<CentralPlayerPro> {
  late AudioEngine _engine;
  Timer? _timer;

  bool _isPlaying = false;
  double _currentPosition = 0;
  double _totalDuration = 0;

  List<double> _eqValues = List.filled(10, 0.0);
  double _masterVolume = 0.8;
  String _currentEqPreset = 'Flat';

  final Map<String, List<double>> _eqPresets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [6.0, 4.0, 2.0, -1.0, -2.0, -1.0, 2.0, 4.0, 5.0, 6.0],
    'Jazz': [4.0, 3.0, 1.0, 2.0, -2.0, -2.0, 0.0, 2.0, 3.0, 4.0],
    'Classical': [5.0, 4.0, 2.0, 1.0, -1.0, -1.0, 0.0, 2.0, 3.0, 4.0],
    'Pop': [-2.0, -1.0, 1.0, 3.0, 4.0, 4.0, 2.0, 0.0, -1.0, -2.0],
    'Bass Boost': [12.0, 9.0, 5.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
  };

  List<AudioTrack> _librarySongs = [];
  int _activeSongIndex = -1;

  @override
  void initState() {
    super.initState();
    // נתיב המנוע שלי RUST NATIVE libaudio_engine עם  - GStreamer 1.28.1 stable bug fix release
    const String libPath =
        '/home/shay/dev/native_audio_engine/target/release/libaudio_engine.so';
    try {
      _engine = AudioEngine(libPath);
      _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_isPlaying) {
          _engine.update();
          setState(() {
            _currentPosition = _engine.position;
            double dur = _engine.duration;
            if (dur > 0) _totalDuration = dur;
            if (_currentPosition > _totalDuration)
              _currentPosition = _totalDuration;
          });
        }
      });
    } catch (e) {
      print("Error loading engine: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // הפונקציה הישנה לבחירת קבצים בודדים
  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'flac', 'wav', 'ogg', 'm4a'],
    );

    if (result != null) {
      _addFilesToLibrary(
        result.files
            .where((f) => f.path != null)
            .map((f) => AudioTrack(title: f.name, path: f.path!))
            .toList(),
      );
    }
  }

  // 🔥 הפיצ'ר החדש: סריקת תיקיות רקורסיבית! 🔥
  Future<void> _pickFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory == null) return;

    final dir = Directory(selectedDirectory);
    // הרקורסיה נמצאת פה: recursive: true
    final List<FileSystemEntity> entities = dir.listSync(recursive: true);
    final validExtensions = ['.mp3', '.flac', '.wav', '.ogg', '.m4a'];

    List<AudioTrack> newTracks = [];
    for (var entity in entities) {
      if (entity is File) {
        final ext = entity.path.toLowerCase();
        if (validExtensions.any((e) => ext.endsWith(e))) {
          // מפריד את שם הקובץ מהנתיב הארוך
          final name = entity.path.split(Platform.pathSeparator).last;
          newTracks.add(AudioTrack(title: name, path: entity.path));
        }
      }
    }

    _addFilesToLibrary(newTracks);
  }

  void _addFilesToLibrary(List<AudioTrack> tracks) {
    setState(() {
      _librarySongs.addAll(tracks);
      if (_activeSongIndex == -1 && _librarySongs.isNotEmpty) {
        _activeSongIndex = 0;
      }
    });
  }

  void _playSong(int index) {
    if (index < 0 || index >= _librarySongs.length) return;
    setState(() {
      _activeSongIndex = index;
      _isPlaying = true;
      _currentPosition = 0;
    });
    _engine.load(_librarySongs[index].path);
    _engine.play();
    _engine.updateMetadata(_librarySongs[index].title, "Unknown Artist");
  }

  void _togglePlayPause() {
    if (_librarySongs.isEmpty) return;
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        if (_currentPosition == 0)
          _engine.load(_librarySongs[_activeSongIndex].path);
        _engine.play();
      } else {
        _engine.pause();
      }
    });
  }

  // שמירת הפלייליסט ל-JSON
  Future<void> _savePlaylist() async {
    if (_librarySongs.isEmpty) return;

    // הופכים את רשימת השירים למבנה של JSON (מילון)
    List<Map<String, String>> playlistData = _librarySongs.map((song) => {
      'title': song.title,
      'path': song.path,
    }).toList();

    String jsonString = jsonEncode(playlistData);

    // פותחים חלון שמירה
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Playlist As...',
      fileName: 'my_playlist.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputFile != null) {
      // כותבים את ה-JSON לקובץ
      await File(outputFile).writeAsString(jsonString);

      // מציגים הודעה קטנה למטה (SnackBar) שהשמירה הצליחה
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Playlist saved to: $outputFile', style: TextStyle(color: Colors.greenAccent))),
      );
    }
  }

  // טעינת פלייליסט מ-JSON
  Future<void> _loadPlaylist() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Load Playlist',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      String path = result.files.single.path!;
      String jsonString = await File(path).readAsString();

      // מפענחים את ה-JSON חזרה לרשימה
      List<dynamic> decoded = jsonDecode(jsonString);

      setState(() {
        _librarySongs.clear(); // מנקים את הרשימה הקיימת
        for (var item in decoded) {
          // נניח שהמחלקה שלך נקראת Song, תשנה לפי מה שהגדרת אצלך
          _librarySongs.add(AudioTrack(title: item['title'], path: item['path']));
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Loaded ${decoded.length} songs!', style: TextStyle(color: Colors.cyanAccent))),
      );
    }
  }



  // פונקציית דמה בינתיים לחלון הצבעים
  void _openThemeColorPicker() {
    // צבע זמני שישמור את מה שהמשתמש בוחר לפני שהוא מאשר
    Color pickerColor = widget.themeColor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: ThemeManager.panelColor,
          title: const Text(
            'בחר צבע לממשק',
            style: TextStyle(
              color: Colors.white,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: pickerColor,
              // הפלטה של הצבעים הזוהרים שמתאימים לנגן שלנו
              availableColors: const [
                Color(0xFFFF0000), // אדום ניאון (ברירת המחדל שלך)
                Color(0xFFD900FF), // סגול (כמו בתמונה השנייה)
                Color(0xFF00B050), // ירוק
                Color(0xFF00E5FF), // תכלת סייברפאנק
                Color(0xFFFF9900), // כתום
                Color(0xFFFF007F), // ורוד חזק
                Color(0xFFFFFFFF), // לבן נקי
                Color(0xFFFACC15), // צהוב
              ],
              onColorChanged: (Color color) {
                pickerColor = color;
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'ביטול',
                style: TextStyle(color: Colors.white54),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: pickerColor),
              child: const Text(
                'החל צבע',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                // 1. מעדכנים את הזיכרון הגלובלי כדי שכל הלחצנים ישנו צבע!
                ThemeManager.updateAccentColor(pickerColor);

                // 2. מעדכנים את המסגרת הראשית
                widget.onThemeChanged(pickerColor);

                Navigator.of(context).pop();
              },
            ),

          ],
        );
      },
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A), // צבע כהה תואם לנגן
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(
              "About Central Player",
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'CustomRB',
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Version: 2.5 Pro (Linux Edition)",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text(
              "Developed by:Shay Kadosh Software Engineering Ashkelon",
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              "Engine: Rust + GStreamer (BASSv2)",
              style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
            ),
            const Divider(color: Colors.white24, height: 30),
            const Text(
              "GStreamer 1.28.0 new major stable release",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CLOSE",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }















  @override
  Widget build(BuildContext context) {
    String currentTitle =
        _activeSongIndex >= 0 && _activeSongIndex < _librarySongs.length
        ? _librarySongs[_activeSongIndex].title
        : "No Track Selected";

    return Scaffold(
      body: Column(
        children: [
          // 🌟 תפריט עליון פעיל 🌟
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // תפריט File
                PopupMenuButton<String>(
                  child:Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Text("File", style: ThemeManager.infoStyle),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'files', child: Text('Add Files...')),
                    const PopupMenuItem(value: 'folder', child: Text('Add Folder (Recursive)...')),
                    const PopupMenuDivider(), // קו הפרדה יפה
                    const PopupMenuItem(value: 'save_playlist', child: Text('Save Playlist (JSON)...')),
                    const PopupMenuItem(value: 'load_playlist', child: Text('Load Playlist (JSON)...')),
                  ],
                  onSelected: (value) {
                    if (value == 'files') _pickFiles();
                    if (value == 'folder') _pickFolder();
                    if (value == 'save_playlist') _savePlaylist();
                    if (value == 'load_playlist') _loadPlaylist();
                  },
                ),

                PopupMenuButton<String>(
                  child:  Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Text("View", style: ThemeManager.infoStyle),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'color', child: Text('Change Theme Color...')),
                    const PopupMenuItem(value: 'font', child: Text('Change Font (Coming Soon)...')),
                  ],
                  onSelected: (value) {
                    if (value == 'color') _openThemeColorPicker();
                  },
                ),

                // תפריט Help - כאן השינוי!
                PopupMenuButton<String>(
                  child:  Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Text("Help", style: ThemeManager.infoStyle),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'about',
                      child: Text('About'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'about') {
                      // כאן אנחנו קוראים לפונקציה של הדיאלוג
                      _showAbout(context);
                    }
                  },
                ),

                const Spacer(),
                const Text(
                  "Central Player Pro v2.5",
                  style: TextStyle(
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),




          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PlayerControlsWidget(
                    currentSongTitle: currentTitle,
                    isPlaying: _isPlaying,
                    currentPosition: _currentPosition,
                    totalDuration: _totalDuration,
                    onPlayPauseToggled: _togglePlayPause,
                    onSeek: (value) {
                      setState(() => _currentPosition = value);

                      // חישוב האחוז (כמה עבר מתוך הסך הכל)
                      if (_totalDuration > 0) {
                        double percent = (value / _totalDuration) * 100;
                        // שליחת האחוז למנוע ה-Rust שלנו!
                        _engine.seek(percent);
                      }
                    },
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24, thickness: 2),

                  Expanded(
                    child: PlaylistWidget(
                      songs: _librarySongs.map((song) => song.title).toList(),
                      activeIndex: _activeSongIndex,
                      onSongSelected: _playSong,
                      onAddFilesPressed: _pickFiles,
                    ),
                  ),

                  EqualizerWidget(
                    eqValues: _eqValues,
                    masterVolume: _masterVolume,
                    currentPreset: _currentEqPreset,
                    onEqChanged: (index, value) {
                      setState(() {
                        _eqValues[index] = value;
                        _currentEqPreset =
                            'Custom'; // אם מזיזים ידנית זה עובר למצב Custom
                      });
                      // שולחים את הפקודה ל-Rust בלייב!
                      _engine.setEq(index, value);
                    },
                    onVolumeChanged: (value) {
                      setState(() => _masterVolume = value);
                      // מכפילים ב-100 כי ה-Rust שלך מצפה לאחוזים (volume_percent)
                      _engine.setVolume(value * 100);
                    },

                    onPresetChanged: (preset) {
                      setState(() {
                        _currentEqPreset = preset;
                        if (_eqPresets.containsKey(preset)) {
                          _eqValues = List.from(_eqPresets[preset]!);
                          // מעדכנים את מנוע ה-Rust לכל 10 הערוצים
                          for (int i = 0; i < 10; i++) {
                            _engine.setEq(i, _eqValues[i]);
                          }
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // שורת סטטוס
          // שורת סטטוס מותאמת
          Container(
            color: ThemeManager.panelColor,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Row(
              children: const [
                Icon(Icons.volume_up, color: Colors.greenAccent, size: 16),
                SizedBox(width: 5),
                Text(
                  "PLAYING",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
                Spacer(),
                Text(
                  "UHD/4K Mode  |  ",
                  style: TextStyle(
                    color: Color.fromARGB(255, 37, 252, 17),
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
                Text(
                  "325.1kHz  ",
                  style: TextStyle(
                    color: Color.fromARGB(255, 222, 249, 13),
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
                Text(
                  "GstremerBASS",
                  style: TextStyle(
                    color: Color.fromARGB(255, 249, 249, 2),
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
                Spacer(),
                Text(
                  "v2.5 Stable",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
