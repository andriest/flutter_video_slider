import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_slider/file_format.dart';
import 'package:video_slider/trim_slider_style.dart';

enum VideoExportPreset {
  none,
  ultrafast,
  superfast,
  veryfast,
  faster,
  fast,
  medium,
  slow,
  slower,
  veryslow
}

///_max = Offset(1.0, 1.0);
const Offset _max = Offset(1.0, 1.0);

///_min = Offset.zero;
const Offset _min = Offset.zero;

class VideoEditorController extends ChangeNotifier {
  ///Constructs a [VideoEditorController] that edits a video from a file.
  VideoEditorController.file(
    this.file, {
    TrimSliderStyle? trimStyle,
  })  : _video = VideoPlayerController.file(file),
        trimStyle = trimStyle ?? TrimSliderStyle();

  ///Style for TrimSlider
  final TrimSliderStyle trimStyle;

  ///Video from [File].
  final File file;

  String get _trimCmd => '-ss $_trimStart -to $_trimEnd';
  String get trimCmd => '-ss $_trimStart -to $_trimEnd';

  Duration get trimmedDuration => _trimEnd - _trimStart;

  bool isTrimming = false;

  double _minTrim = _min.dx;
  double _maxTrim = _max.dx;

  Offset _minCrop = _min;
  Offset _maxCrop = _max;

  Duration _trimEnd = Duration.zero;
  Duration _trimStart = Duration.zero;
  final VideoPlayerController _video;

  ///Get the `VideoPlayerController`
  VideoPlayerController get video => _video;

  ///Get the `VideoPlayerController.value.initialized`
  bool get initialized => _video.value.isInitialized;

  ///Get the `VideoPlayerController.value.position`
  Duration get videoPosition => _video.value.position;

  ///Get the `VideoPlayerController.value.duration`
  Duration get videoDuration => _video.value.duration;

  ///The **MinTrim** (Range is `0.0` to `1.0`).
  double get minTrim => _minTrim;
  set minTrim(double value) {
    if (value >= _min.dx && value <= _max.dx) {
      _minTrim = value;
      _updateTrimRange();
    }
  }

  ///The **MaxTrim** (Range is `0.0` to `1.0`).
  double get maxTrim => _maxTrim;
  set maxTrim(double value) {
    if (value >= _min.dx && value <= _max.dx) {
      _maxTrim = value;
      _updateTrimRange();
    }
  }

  ///The **TopLeft Offset** (Range is `Offset(0.0, 0.0)` to `Offset(1.0, 1.0)`).
  Offset get minCrop => _minCrop;
  set minCrop(Offset value) {
    if (value >= _min && value <= _max) {
      _minCrop = value;
      notifyListeners();
    }
  }

  ///The **BottomRight Offset** (Range is `Offset(0.0, 0.0)` to `Offset(1.0, 1.0)`).
  Offset get maxCrop => _maxCrop;
  set maxCrop(Offset value) {
    if (value >= _min && value <= _max) {
      _maxCrop = value;
      notifyListeners();
    }
  }

  //----------------//
  //VIDEO CONTROLLER//
  //----------------//
  ///Attempts to open the given [File] and load metadata about the video.
  Future<void> initialize() async {
    try {
      await _video.initialize();
      _video.addListener(_videoListener);
      await _video.setLooping(true);
      _updateTrimRange();
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing video: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      if (_video.value.isPlaying) {
        await _video.pause();
      }
      _video.removeListener(_videoListener);
      await _video.dispose();
      
      // Cancel semua FFmpeg sessions yang sedang berjalan
      final executions = await FFmpegKit.listSessions();
      if (executions.isNotEmpty) {
        await FFmpegKit.cancel();
      }
    } catch (e) {
      debugPrint('Error disposing VideoEditorController: $e');
    } finally {
      super.dispose();
    }
  }

  void _videoListener() {
    try {
      final position = videoPosition;
      if (position < _trimStart || position >= _trimEnd) {
        _video.seekTo(_trimStart);
      }
    } catch (e) {
      debugPrint('Error in video listener: $e');
    }
  }

  //----------//
  //VIDEO TRIM//
  //----------//
  void _updateTrimRange() {
    final duration = videoDuration;
    if (duration > Duration.zero) {
      _trimStart = duration * minTrim;
      _trimEnd = duration * maxTrim;
      
      // Pastikan trim range valid
      if (_trimStart >= _trimEnd) {
        _trimEnd = _trimStart + const Duration(seconds: 1);
        if (_trimEnd > duration) {
          _trimEnd = duration;
          _trimStart = _trimEnd - const Duration(seconds: 1);
          if (_trimStart < Duration.zero) {
            _trimStart = Duration.zero;
          }
        }
      }
    }
    notifyListeners();
  }

  void initTrim(Duration durationStart, Duration durationEnd) {
    final duration = videoDuration;
    if (duration > Duration.zero) {
      // Validasi dan normalisasi trim range
      _trimStart = _clampDuration(durationStart, Duration.zero, duration);
      _trimEnd = _clampDuration(durationEnd, _trimStart + const Duration(seconds: 1), duration);
    } else {
      _trimStart = durationStart;
      _trimEnd = durationEnd;
    }
    notifyListeners();
  }

  void setTrimStart(Duration duration) {
    final videoDuration = this.videoDuration;
    if (videoDuration > Duration.zero) {
      _trimStart = _clampDuration(duration, Duration.zero, videoDuration);
      // Pastikan trim end masih valid
      if (_trimStart >= _trimEnd) {
        _trimEnd = _clampDuration(_trimStart + const Duration(seconds: 1), Duration.zero, videoDuration);
      }
    } else {
      _trimStart = duration;
    }
    notifyListeners();
  }

  void setTrimEnd(Duration duration) {
    final videoDuration = this.videoDuration;
    if (videoDuration > Duration.zero) {
      _trimEnd = _clampDuration(duration, _trimStart + const Duration(seconds: 1), videoDuration);
    } else {
      _trimEnd = duration;
    }
    notifyListeners();
  }

  /// Helper method untuk clamp Duration
  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Debug method untuk export validation
  void _debugExportState() {
    debugPrint('=== EXPORT DEBUG INFO ===');
    debugPrint('File exists: ${file.existsSync()}');
    debugPrint('File path: ${file.path}');
    debugPrint('Video initialized: $initialized');
    debugPrint('Video duration: $videoDuration');
    debugPrint('Trim start: $_trimStart');
    debugPrint('Trim end: $_trimEnd');
    debugPrint('Trimmed duration: $trimmedDuration');
    debugPrint('Min trim: $minTrim');
    debugPrint('Max trim: $maxTrim');
    debugPrint('========================');
  }

  Future<String> getOutputPath({
    required String filePath,
    String? name,
    String? outputDirectory,
    required FileFormat format,
  }) async {
    try {
      final tempPath = outputDirectory ?? (await getTemporaryDirectory()).path;
      name ??= path.basenameWithoutExtension(filePath);
      
      // Sanitize filename untuk menghindari karakter yang tidak valid
      final sanitizedName = name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final epoch = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '$tempPath/${sanitizedName}_$epoch.${format.extension}';
      
      // Pastikan directory output ada
      final outputDir = Directory(path.dirname(outputPath));
      if (!outputDir.existsSync()) {
        await outputDir.create(recursive: true);
      }
      
      return outputPath;
    } catch (e) {
      throw Exception('Failed to create output path: $e');
    }
  }

  static Future<void> deleteAllCache({String? outputDirectory}) async {
    try {
      final tempPath = outputDirectory ?? (await getTemporaryDirectory()).path;
      final directory = Directory(tempPath);
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    } catch (e) {
      debugPrint('Error deleting cache: $e');
    }
  }

  Future<void> exportVideo({
    required void Function(File file) onCompleted,
    void Function(Object, StackTrace)? onError,
    String? name,
    String? outDir,
    VideoExportFormat format = VideoExportFormat.mp4,
    double scale = 1.0,
    String? customInstruction,
    void Function(Statistics, double)? onProgress,
    VideoExportPreset preset = VideoExportPreset.none,
    bool isFiltersEnabled = true,
  }) async {
    try {
      // Debug export state
      _debugExportState();
      // Validasi file input
      if (!file.existsSync()) {
        if (onError != null) {
          onError(
            Exception('Input video file does not exist: ${file.path}'),
            StackTrace.current,
          );
        }
        return;
      }

      // Validasi video duration
      if (videoDuration == Duration.zero) {
        if (onError != null) {
          onError(
            Exception('Video duration is zero. Make sure video is properly initialized.'),
            StackTrace.current,
          );
        }
        return;
      }

      // Validasi trim duration
      if (_trimStart >= _trimEnd) {
        if (onError != null) {
          onError(
            Exception('Invalid trim range: start ($_trimStart) must be less than end ($_trimEnd)'),
            StackTrace.current,
          );
        }
        return;
      }

      // Validasi minimum trim duration (0.1 detik)
      if (trimmedDuration < const Duration(milliseconds: 100)) {
        if (onError != null) {
          onError(
            Exception('Trim duration must be at least 0.1 second. Current duration: $trimmedDuration'),
            StackTrace.current,
          );
        }
        return;
      }

      final videoPath = file.path;
      final outputPath = await getOutputPath(
        filePath: videoPath,
        name: name,
        outputDirectory: outDir,
        format: format,
      );

      // Perbaiki command building - FFmpegKit tidak memerlukan prefix ffmpeg
      final execute = '-i "${videoPath}" ${customInstruction ?? ""} ${_getPreset(preset)} $_trimCmd -y "${outputPath}"';

      debugPrint('VideoEditor - run export video command : [$execute]');
      debugPrint('VideoEditor - input file: $videoPath');
      debugPrint('VideoEditor - output path: $outputPath');
      debugPrint('VideoEditor - trim start: $_trimStart');
      debugPrint('VideoEditor - trim end: $_trimEnd');
      debugPrint('VideoEditor - video duration: $videoDuration');

      // PROGRESS CALLBACKS
      await FFmpegKit.executeAsync(
        execute,
        (session) async {
          try {
            final state = FFmpegKitConfig.sessionStateToString(await session.getState());
            final code = await session.getReturnCode();
            final output = await session.getOutput();

            if (ReturnCode.isSuccess(code)) {
              // Validasi file output sebelum callback
              final outputFile = File(outputPath);
              if (outputFile.existsSync()) {
                onCompleted(outputFile);
              } else {
                if (onError != null) {
                  onError(
                    Exception('Output file was not created: $outputPath'),
                    StackTrace.current,
                  );
                }
              }
            } else {
              debugPrint('FFmpeg failed - State: $state, Code: $code, Output: $output');
              if (onError != null) {
                onError(
                  Exception(
                    'FFmpeg process failed:\n'
                    'State: $state\n'
                    'Return Code: $code\n'
                    'Output: $output\n'
                    'Command: $execute\n'
                    'Input file exists: ${File(videoPath).existsSync()}\n'
                    'Output directory exists: ${Directory(path.dirname(outputPath)).existsSync()}'
                  ),
                  StackTrace.current,
                );
              }
            }
          } catch (e) {
            if (onError != null) {
              onError(e, StackTrace.current);
            }
          }
        },
        null,
        onProgress != null
            ? (stats) {
                try {
                  // Progress value of encoded video
                  final timeMs = stats.getTime();
                  final durationMs = trimmedDuration.inMilliseconds;
                  if (durationMs > 0) {
                    final progressValue = timeMs / durationMs;
                    onProgress(stats, progressValue.clamp(0.0, 1.0));
                  }
                } catch (e) {
                  debugPrint('Error calculating progress: $e');
                }
              }
            : null,
      );
    } catch (e) {
      if (onError != null) {
        onError(e, StackTrace.current);
      }
    }
  }

  String _getPreset(VideoExportPreset preset) {
    String newPreset = '';

    switch (preset) {
      case VideoExportPreset.ultrafast:
        newPreset = 'ultrafast';
        break;
      case VideoExportPreset.superfast:
        newPreset = 'superfast';
        break;
      case VideoExportPreset.veryfast:
        newPreset = 'veryfast';
        break;
      case VideoExportPreset.faster:
        newPreset = 'faster';
        break;
      case VideoExportPreset.fast:
        newPreset = 'fast';
        break;
      case VideoExportPreset.medium:
        newPreset = 'medium';
        break;
      case VideoExportPreset.slow:
        newPreset = 'slow';
        break;
      case VideoExportPreset.slower:
        newPreset = 'slower';
        break;
      case VideoExportPreset.veryslow:
        newPreset = 'veryslow';
        break;
      case VideoExportPreset.none:
        newPreset = '';
        break;
    }

    return newPreset.isEmpty ? "" : "-preset $newPreset";
  }

  ///Get the **VideoPosition** (Range is `0.0` to `1.0`).
  double get trimPosition {
    try {
      final duration = videoDuration.inMilliseconds;
      if (duration > 0) {
        return videoPosition.inMilliseconds / duration;
      }
      return 0.0;
    } catch (e) {
      debugPrint('Error calculating trim position: $e');
      return 0.0;
    }
  }
}
