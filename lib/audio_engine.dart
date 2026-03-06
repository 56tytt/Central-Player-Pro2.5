import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

// ==========================================
// 1. הגדרת החתימות (Signatures) ל-FFI
// ==========================================
typedef EngineNewNative = ffi.Pointer Function();
typedef EngineNewDart = ffi.Pointer Function();

typedef EnginePlayNative = ffi.Void Function(ffi.Pointer);
typedef EnginePlayDart = void Function(ffi.Pointer);

typedef EnginePauseNative = ffi.Void Function(ffi.Pointer);
typedef EnginePauseDart = void Function(ffi.Pointer);

typedef EngineLoadNative = ffi.Void Function(ffi.Pointer, ffi.Pointer<Utf8>);
typedef EngineLoadDart = void Function(ffi.Pointer, ffi.Pointer<Utf8>);

typedef EngineUpdateNative = ffi.Bool Function(ffi.Pointer);
typedef EngineUpdateDart = bool Function(ffi.Pointer);

typedef EngineGetPositionNative = ffi.Double Function(ffi.Pointer);
typedef EngineGetPositionDart = double Function(ffi.Pointer);

typedef EngineGetDurationNative = ffi.Double Function(ffi.Pointer);
typedef EngineGetDurationDart = double Function(ffi.Pointer);

typedef EngineSetEqNative =
    ffi.Void Function(ffi.Pointer, ffi.Size, ffi.Double);
typedef EngineSetEqDart = void Function(ffi.Pointer, int, double);

typedef EngineSeekNative = ffi.Void Function(ffi.Pointer, ffi.Float);
typedef EngineSeekDart = void Function(ffi.Pointer, double);

typedef EngineSetVolumeNative = ffi.Void Function(ffi.Pointer, ffi.Float);
typedef EngineSetVolumeDart = void Function(ffi.Pointer, double);

// חתימה ל-MPRIS
typedef EngineUpdateMprisNative =
    ffi.Void Function(ffi.Pointer, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);
typedef EngineUpdateMprisDart =
    void Function(ffi.Pointer, ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);

// ==========================================
// 2. מחלקת המנוע (Audio Engine)
// ==========================================
class AudioEngine {
  late ffi.DynamicLibrary _lib;
  late ffi.Pointer _enginePtr;

  late EnginePlayDart _playFunc;
  late EnginePauseDart _pauseFunc;
  late EngineLoadDart _loadFunc;
  late EngineUpdateDart _updateFunc;
  late EngineGetPositionDart _getPositionFunc;
  late EngineGetDurationDart _getDurationFunc;
  late EngineSetEqDart _setEqFunc;
  late EngineSeekDart _seekFunc;
  late EngineSetVolumeDart _setVolumeFunc;
  late EngineUpdateMprisDart _updateMprisFunc; // המשתנה החדש

  AudioEngine(String libraryPath) {
    _lib = ffi.DynamicLibrary.open(libraryPath);

    final newFunc = _lib.lookupFunction<EngineNewNative, EngineNewDart>(
      'engine_new',
    );
    _playFunc = _lib.lookupFunction<EnginePlayNative, EnginePlayDart>(
      'engine_play',
    );
    _pauseFunc = _lib.lookupFunction<EnginePauseNative, EnginePauseDart>(
      'engine_pause',
    );
    _loadFunc = _lib.lookupFunction<EngineLoadNative, EngineLoadDart>(
      'engine_load',
    );
    _updateFunc = _lib.lookupFunction<EngineUpdateNative, EngineUpdateDart>(
      'engine_update',
    );
    _getPositionFunc = _lib
        .lookupFunction<EngineGetPositionNative, EngineGetPositionDart>(
          'engine_get_position',
        );
    _getDurationFunc = _lib
        .lookupFunction<EngineGetDurationNative, EngineGetDurationDart>(
          'engine_get_duration',
        );
    _setEqFunc = _lib.lookupFunction<EngineSetEqNative, EngineSetEqDart>(
      'engine_set_eq',
    );
    _seekFunc = _lib.lookupFunction<EngineSeekNative, EngineSeekDart>(
      'engine_seek',
    );
    _setVolumeFunc = _lib
        .lookupFunction<EngineSetVolumeNative, EngineSetVolumeDart>(
          'engine_set_volume',
        );

    // קישור הפונקציה של ה-MPRIS
    _updateMprisFunc = _lib
        .lookupFunction<EngineUpdateMprisNative, EngineUpdateMprisDart>(
          'engine_update_mpris_metadata',
        );

    _enginePtr = newFunc();
  }

  void load(String path) {
    final pathPtr = path.toNativeUtf8();
    _loadFunc(_enginePtr, pathPtr);
    malloc.free(pathPtr);
  }

  void play() => _playFunc(_enginePtr);
  void pause() => _pauseFunc(_enginePtr);
  bool update() => _updateFunc(_enginePtr);

  double get position => _getPositionFunc(_enginePtr);
  double get duration => _getDurationFunc(_enginePtr);

  void setEq(int bandIndex, double gain) =>
      _setEqFunc(_enginePtr, bandIndex, gain);
  void seek(double percent) => _seekFunc(_enginePtr, percent);
  void setVolume(double volume) => _setVolumeFunc(_enginePtr, volume);

  // הנה הפונקציה שהייתה חסרה לך!
  void updateMetadata(String title, String artist) {
    final titlePtr = title.toNativeUtf8();
    final artistPtr = artist.toNativeUtf8();
    _updateMprisFunc(_enginePtr, titlePtr, artistPtr);
    malloc.free(titlePtr);
    malloc.free(artistPtr);
  }
}
