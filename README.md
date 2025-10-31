# video_slider

A simple video slider to trim by specific area with robust error handling and Flutter 3.24.0+ support.

[![pub ver](https://img.shields.io/badge/pub-v0.0.2-blue)](https://pub.dev/packages/video_slider)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)](https://github.com/YuheiNakasaka/)

![RPReplay_Final1626501540](https://user-images.githubusercontent.com/1421093/126027540-0bdeca06-5167-420c-9f36-2c37c2ba0862.gif)

This library is inspired by [video_editor](https://github.com/seel-channel/video_editor). Almost slider code is copied from the library. What I did is to extract only slider from other dependencies like player, cropper and ffmpeg. You can combine a original player or trimming methods which you want to use with this simple slider.

## Features

- ✅ **Video Trimming**: Trim videos by selecting specific time ranges
- ✅ **Thumbnail Generation**: Automatic thumbnail generation for video preview
- ✅ **Video Export**: Export trimmed videos with various formats (MP4, AVI, MOV, GIF)
- ✅ **Customizable Styling**: Customize slider appearance and colors
- ✅ **Error Handling**: Robust error handling with detailed error messages
- ✅ **Flutter 3.24.0+ Support**: Updated for Flutter 3.24.0+
- ✅ **Cross-platform**: Works on Android, iOS, and Web

## Requirements

- **SDK**: >=3.0.0 <4.0.0
- **Flutter**: >=3.24.0

## Installation

Add the dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  video_slider: ^0.0.2
```

## Usage

### Basic Usage

```dart
import 'package:video_slider/video_slider.dart';

// Create controller
final controller = VideoEditorController.file(File('path/to/video.mp4'));

// Initialize controller
await controller.initialize();

// Use VideoSlider widget
Container(
  width: MediaQuery.of(context).size.width - 40,
  height: 60,
  margin: const EdgeInsets.symmetric(horizontal: 20),
  child: VideoSlider(
    controller: controller,
    height: 60,
    maxDuration: const Duration(seconds: 15),
  ),
)
```

### Video Export

```dart
await controller.exportVideo(
  onCompleted: (File file) {
    print('Video exported: ${file.path}');
  },
  onError: (error, stackTrace) {
    print('Export error: $error');
  },
  onProgress: (stats, progress) {
    print('Progress: ${(progress * 100).toStringAsFixed(1)}%');
  },
  format: VideoExportFormat.mp4,
  preset: VideoExportPreset.medium,
);
```

### Custom Styling

```dart
final controller = VideoEditorController.file(
  File('path/to/video.mp4'),
  trimStyle: TrimSliderStyle(
    background: Colors.black.withOpacity(0.6),
    dotColor: Colors.white,
    lineColor: Colors.white,
    positionLineColor: Colors.red,
    dotRadius: 5,
    lineWidth: 2,
  ),
);
```

## API Reference

### VideoEditorController

#### Constructor
- `VideoEditorController.file(File file, {TrimSliderStyle? trimStyle})`

#### Methods
- `Future<void> initialize()` - Initialize the video controller
- `Future<void> dispose()` - Dispose the controller and cleanup resources
- `Future<void> exportVideo({...})` - Export trimmed video
- `void initTrim(Duration start, Duration end)` - Set trim range
- `void setTrimStart(Duration duration)` - Set trim start time
- `void setTrimEnd(Duration duration)` - Set trim end time

#### Properties
- `File file` - Input video file
- `VideoPlayerController video` - Video player controller
- `bool initialized` - Whether controller is initialized
- `Duration videoDuration` - Total video duration
- `Duration trimmedDuration` - Duration of trimmed section
- `double minTrim` - Minimum trim position (0.0 to 1.0)
- `double maxTrim` - Maximum trim position (0.0 to 1.0)

### VideoSlider

#### Constructor
- `VideoSlider({required VideoEditorController controller, double height = 60, int quality = 10, Duration? maxDuration})`

#### Parameters
- `controller` - VideoEditorController instance
- `height` - Height of the slider
- `quality` - Thumbnail quality (0-100)
- `maxDuration` - Maximum duration that can be trimmed

## Error Handling

The library includes comprehensive error handling:

- **File Validation**: Checks if input video file exists
- **Duration Validation**: Validates video duration and trim ranges
- **FFmpeg Errors**: Detailed error messages for FFmpeg failures
- **Path Sanitization**: Handles invalid characters in file paths
- **Progress Callbacks**: Safe progress calculation with error handling

## Dependencies

- `ffmpeg_kit_flutter: ^6.0.3` - Video processing
- `video_player: ^2.9.2` - Video playback
- `video_thumbnail: ^0.5.6` - Thumbnail generation
- `path_provider: ^2.1.4` - File path management
- `path: ^1.9.0` - Path utilities

## Example

See the [example](https://github.com/YuheiNakasaka/video_slider/tree/master/example) directory for a complete working example.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
