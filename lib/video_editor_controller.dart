import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/statistics.dart';
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
    await _video.initialize();
    _video.addListener(_videoListener);
    await _video.setLooping(true);
    _updateTrimRange();
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    if (_video.value.isPlaying) {
      await _video.pause();
    }
    _video.removeListener(_videoListener);
    await _video.dispose();
    final executions = await FFmpegKit.listSessions();
    if (executions.isNotEmpty) {
      await FFmpegKit.cancel();
    }
    super.dispose();
  }

  void _videoListener() {
    final position = videoPosition;
    if (position < _trimStart || position >= _trimEnd) {
      _video.seekTo(_trimStart);
    }
  }

  //----------//
  //VIDEO TRIM//
  //----------//
  void _updateTrimRange() {
    final duration = videoDuration;
    _trimStart = duration * minTrim;
    _trimEnd = duration * maxTrim;
    notifyListeners();
  }

  Future<String> _getOutputPath({
    required String filePath,
    String? name,
    String? outputDirectory,
    required FileFormat format,
  }) async {
    final tempPath = outputDirectory ?? (await getTemporaryDirectory()).path;
    name ??= path.basenameWithoutExtension(filePath);
    final epoch = DateTime.now().millisecondsSinceEpoch;
    return '$tempPath/${name}_$epoch.${format.extension}';
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
    final videoPath = file.path;
    final outputPath = await _getOutputPath(
      filePath: videoPath,
      name: name,
      outputDirectory: outDir,
      format: format,
    );
    // final String filter = _getExportFilters(
    //   videoFormat: format,
    //   scale: scale,
    //   isFiltersEnabled: isFiltersEnabled,
    // );
    final execute =
        // ignore: unnecessary_string_escapes
        " -i \'$videoPath\' ${customInstruction ?? ""} ${_getPreset(preset)} $_trimCmd -y \"$outputPath\"";

    debugPrint('VideoEditor - run export video command : [$execute]');

    // PROGRESS CALLBACKS
    await FFmpegKit.executeAsync(
      execute,
      (session) async {
        final state =
            FFmpegKitConfig.sessionStateToString(await session.getState());
        final code = await session.getReturnCode();

        if (ReturnCode.isSuccess(code)) {
          onCompleted(File(outputPath));
        } else {
          if (onError != null) {
            onError(
              Exception(
                  'FFmpeg process exited with state $state and return code $code.\n${await session.getOutput()}'),
              StackTrace.current,
            );
          }
          return;
        }
      },
      null,
      onProgress != null
          ? (stats) {
              // Progress value of encoded video
              final progressValue =
                  stats.getTime() / trimmedDuration.inMilliseconds;
              onProgress(stats, progressValue.clamp(0.0, 1.0));
            }
          : null,
    );
  }

  String _getPreset(VideoExportPreset preset) {
    String? newPreset = '';

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
  double get trimPosition =>
      videoPosition.inMilliseconds / videoDuration.inMilliseconds;
}
