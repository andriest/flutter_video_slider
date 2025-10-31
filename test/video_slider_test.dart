import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_slider/video_slider.dart';

void main() {
  group('VideoEditorController Tests', () {
    late VideoEditorController controller;
    late File testVideoFile;

    setUpAll(() async {
      // Create a dummy video file for testing
      testVideoFile = File('test_video.mp4');
      await testVideoFile.writeAsBytes(List.filled(1024, 0)); // 1KB dummy file
    });

    tearDownAll(() async {
      // Clean up test file
      if (await testVideoFile.exists()) {
        await testVideoFile.delete();
      }
    });

    setUp(() {
      controller = VideoEditorController.file(testVideoFile);
    });

    tearDown(() {
      controller.dispose();
    });

    test('should initialize with valid file', () async {
      expect(controller.file, testVideoFile);
      expect(controller.initialized, false);
    });

    test('should validate trim range correctly', () {
      // Test initial trim values
      expect(controller.minTrim, 0.0);
      expect(controller.maxTrim, 1.0);
      expect(controller.trimmedDuration, Duration.zero);
    });

    test('should handle trim range updates', () {
      controller.minTrim = 0.2;
      controller.maxTrim = 0.8;
      
      expect(controller.minTrim, 0.2);
      expect(controller.maxTrim, 0.8);
    });

    test('should validate trim range bounds', () {
      // Test invalid trim values
      controller.minTrim = 1.5; // Should be clamped to 1.0
      controller.maxTrim = -0.5; // Should be clamped to 0.0
      
      expect(controller.minTrim, 1.0);
      expect(controller.maxTrim, 0.0);
    });

    test('should generate correct trim command', () {
      controller.setTrimStart(const Duration(seconds: 5));
      controller.setTrimEnd(const Duration(seconds: 10));
      
      expect(controller.trimCmd, '-ss 0:00:05.000000 -to 0:00:10.000000');
    });

    test('should handle file path sanitization', () async {
      final outputPath = await controller.getOutputPath(
        filePath: 'test/path/video.mp4',
        name: 'test<>:"/\\|?*file',
        format: VideoExportFormat.mp4,
      );
      
      expect(outputPath, contains('test______file'));
      expect(outputPath, endsWith('.mp4'));
    });
  });

  group('VideoSlider Widget Tests', () {
    test('should create VideoSlider with required parameters', () {
      final controller = VideoEditorController.file(File('test.mp4'));
      final slider = VideoSlider(
        controller: controller,
        height: 60,
        maxDuration: const Duration(minutes: 5),
      );
      
      expect(slider.controller, controller);
      expect(slider.height, 60);
      expect(slider.maxDuration, const Duration(minutes: 5));
    });
  });

  group('FileFormat Tests', () {
    test('should create VideoExportFormat correctly', () {
      const mp4Format = VideoExportFormat.mp4;
      const aviFormat = VideoExportFormat.avi;
      const customFormat = VideoExportFormat('mkv');
      
      expect(mp4Format.extension, 'mp4');
      expect(aviFormat.extension, 'avi');
      expect(customFormat.extension, 'mkv');
    });

    test('should create GifExportFormat correctly', () {
      const gifFormat = GifExportFormat();
      const gifFormatCustomFps = GifExportFormat(fps: 15);
      
      expect(gifFormat.extension, 'gif');
      expect(gifFormat.fps, 10);
      expect(gifFormatCustomFps.fps, 15);
    });
  });
}
