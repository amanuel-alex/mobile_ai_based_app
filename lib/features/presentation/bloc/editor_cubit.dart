import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'editor_state.dart';

class _ImageAnalysis {
  final bool isDark;
  final bool isLowContrast;
  final bool isLowSaturation;
  final double averageBrightness;

  _ImageAnalysis({
    required this.isDark,
    required this.isLowContrast,
    required this.isLowSaturation,
    required this.averageBrightness,
  });
}

class EditorCubit extends Cubit<EditorState> {
  EditorCubit() : super(const EditorState());

  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> _history = [];
  final List<Uint8List> _redoStack = [];
  int _historyIndex = -1;
  static const int _maxHistorySize = 20;

  // === IMAGE PICKING ===
  Future<void> pickImage() async {
    try {
      emit(state.copyWith(status: EditorStatus.loading));

      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (file == null) {
        emit(state.copyWith(status: EditorStatus.initial));
        return;
      }

      final bytes = await file.readAsBytes();
      _pushHistory(bytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        originalBytes: bytes,
        editedBytes: bytes,
        fileName: file.name,
        fileSize: bytes.length,
        message: 'Image loaded successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Failed to pick image: ${e.toString()}',
      ));
    }
  }

  Future<void> pickImageFromCamera() async {
    try {
      emit(state.copyWith(status: EditorStatus.loading));

      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (file == null) {
        emit(state.copyWith(status: EditorStatus.initial));
        return;
      }

      final bytes = await file.readAsBytes();
      _pushHistory(bytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        originalBytes: bytes,
        editedBytes: bytes,
        fileName: file.name,
        fileSize: bytes.length,
        message: 'Photo captured successfully!',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Failed to capture image: ${e.toString()}',
      ));
    }
  }

  // === HISTORY MANAGEMENT ===
  void _pushHistory(Uint8List bytes) {
    if (_history.length >= _maxHistorySize) {
      _history.removeAt(0);
      _historyIndex = math.max(_historyIndex - 1, 0);
    }

    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(Uint8List.fromList(bytes));
    _historyIndex = _history.length - 1;
    _updateHistoryState();
  }

  void _updateHistoryState() {
    emit(state.copyWith(
      canUndo: _historyIndex > 0,
      canRedo: _historyIndex < _history.length - 1,
    ));
  }

  void undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      final bytes = _history[_historyIndex];
      _redoStack.add(bytes);
      emit(state.copyWith(
        editedBytes: bytes,
        status: EditorStatus.success,
        canUndo: _historyIndex > 0,
        canRedo: true,
        message: 'Undo successful',
      ));
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      final bytes = _redoStack.removeLast();
      _history.add(bytes);
      _historyIndex = _history.length - 1;
      emit(state.copyWith(
        editedBytes: bytes,
        status: EditorStatus.success,
        canUndo: true,
        canRedo: _redoStack.isNotEmpty,
        message: 'Redo successful',
      ));
    }
  }

  // === REAL-TIME ADJUSTMENTS ===
  void updateAdjustments({
    double? brightness,
    double? contrast,
    double? saturation,
    double? exposure,
    double? warmth,
    double? highlights,
    double? shadows,
    double? sharpness,
    double? vignette,
    double? blur,
  }) {
    final newState = state.copyWith(
      brightness: brightness ?? state.brightness,
      contrast: contrast ?? state.contrast,
      saturation: saturation ?? state.saturation,
      exposure: exposure ?? state.exposure,
      warmth: warmth ?? state.warmth,
      highlights: highlights ?? state.highlights,
      shadows: shadows ?? state.shadows,
      sharpness: sharpness ?? state.sharpness,
      vignette: vignette ?? state.vignette,
      blur: blur ?? state.blur,
    );

    emit(newState);

    // Apply adjustments in real-time
    if (state.originalBytes != null) {
      _applyAdjustmentsRealTime();
    }
  }

  Future<void> _applyAdjustmentsRealTime() async {
    try {
      if (state.originalBytes == null) return;

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) return;

      img.Image processedImage = img.copyResize(
        originalImage,
        width: originalImage.width,
        height: originalImage.height,
      );

      // Apply all adjustments
      processedImage = _applyBasicAdjustments(processedImage);
      processedImage = _applyAdvancedAdjustments(processedImage);

      // Apply blur if needed
      if (state.blur > 0) {
        final radius = (state.blur.clamp(0.0, 1.0) * 15).toInt();
        processedImage = img.gaussianBlur(processedImage, radius: radius);
      }

      final resultBytes =
          Uint8List.fromList(img.encodeJpg(processedImage, quality: 95));

      emit(state.copyWith(editedBytes: resultBytes));
    } catch (e) {
      print('Real-time adjustment error: $e');
    }
  }

  img.Image _applyBasicAdjustments(img.Image image) {
    // Apply brightness with visible effect
    if (state.brightness.abs() > 0.01) {
      final brightnessValue = (state.brightness.clamp(-1.0, 1.0) * 100).toInt();
      image = img.adjustColor(image, brightness: brightnessValue);
    }

    // Apply contrast with visible effect
    if (state.contrast.abs() > 0.01) {
      final contrastValue = (state.contrast.clamp(-1.0, 1.0) * 100).toInt();
      image = img.adjustColor(image, contrast: contrastValue);
    }

    // Apply saturation with visible effect
    if (state.saturation.abs() > 0.01) {
      final saturationValue = (state.saturation.clamp(-1.0, 1.0) * 100).toInt();
      image = img.adjustColor(image, saturation: saturationValue);
    }

    return image;
  }

  img.Image _applyAdvancedAdjustments(img.Image image) {
    // Apply exposure
    if (state.exposure.abs() > 0.01) {
      final exposureValue = state.exposure.clamp(-1.0, 1.0) * 2.0;
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final factor = math.pow(2.0, exposureValue).toDouble();
          final r = (pixel.r * factor).clamp(0, 255).toInt();
          final g = (pixel.g * factor).clamp(0, 255).toInt();
          final b = (pixel.b * factor).clamp(0, 255).toInt();
          image.setPixelRgba(x, y, r, g, b, pixel.a);
        }
      }
    }

    // Apply warmth (color temperature)
    if (state.warmth.abs() > 0.01) {
      final warmthValue = state.warmth.clamp(-1.0, 1.0) * 50;
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = (pixel.r + warmthValue).clamp(0, 255).toInt();
          final b = (pixel.b - warmthValue).clamp(0, 255).toInt();
          image.setPixelRgba(x, y, r, pixel.g, b, pixel.a);
        }
      }
    }

    // Apply sharpness
    if (state.sharpness > 0.01) {
      final blurred = img.gaussianBlur(image, radius: 2);
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final original = image.getPixel(x, y);
          final blur = blurred.getPixel(x, y);
          final amount = state.sharpness.clamp(0.0, 2.0);

          final r = (original.r + amount * (original.r - blur.r))
              .clamp(0, 255)
              .toInt();
          final g = (original.g + amount * (original.g - blur.g))
              .clamp(0, 255)
              .toInt();
          final b = (original.b + amount * (original.b - blur.b))
              .clamp(0, 255)
              .toInt();

          image.setPixelRgba(x, y, r, g, b, original.a);
        }
      }
    }

    // Apply vignette
    if (state.vignette > 0.01) {
      final strength = state.vignette.clamp(0.0, 1.0);
      final centerX = image.width / 2;
      final centerY = image.height / 2;
      final maxDistance = math.sqrt(centerX * centerX + centerY * centerY);

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final dx = x - centerX;
          final dy = y - centerY;
          final distance = math.sqrt(dx * dx + dy * dy);
          final vignette = 1.0 - (distance / maxDistance) * strength;

          final pixel = image.getPixel(x, y);
          final r = (pixel.r * vignette).clamp(0, 255).toInt();
          final g = (pixel.g * vignette).clamp(0, 255).toInt();
          final b = (pixel.b * vignette).clamp(0, 255).toInt();

          image.setPixelRgba(x, y, r, g, b, pixel.a);
        }
      }
    }

    return image;
  }

  Future<void> applyAdjustments() async {
    try {
      if (state.originalBytes == null) return;

      emit(state.copyWith(status: EditorStatus.loading, isProcessing: true));

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) throw Exception('Unable to decode image');

      img.Image processedImage = img.copyResize(
        originalImage,
        width: originalImage.width,
        height: originalImage.height,
      );

      // Apply all adjustments
      processedImage = _applyBasicAdjustments(processedImage);
      processedImage = _applyAdvancedAdjustments(processedImage);

      final resultBytes =
          Uint8List.fromList(img.encodeJpg(processedImage, quality: 95));
      _pushHistory(resultBytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        editedBytes: resultBytes,
        message: 'Adjustments applied successfully!',
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Failed to apply adjustments: ${e.toString()}',
        isProcessing: false,
      ));
    }
  }

  // === FILTERS ===
  Future<void> applyFilter(String filterId) async {
    try {
      if (state.originalBytes == null) return;

      emit(state.copyWith(status: EditorStatus.loading, isProcessing: true));

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) throw Exception('Unable to decode image');

      img.Image filteredImage = img.copyResize(
        originalImage,
        width: originalImage.width,
        height: originalImage.height,
      );

      // Reset adjustments when applying filter
      emit(state.copyWith(
        brightness: 0.0,
        contrast: 0.0,
        saturation: 0.0,
        exposure: 0.0,
        warmth: 0.0,
        sharpness: 0.0,
        vignette: 0.0,
        blur: 0.0,
      ));

      switch (filterId) {
        case 'vivid':
          filteredImage =
              img.adjustColor(filteredImage, saturation: 50, contrast: 30);
          break;
        case 'dramatic':
          filteredImage =
              img.adjustColor(filteredImage, contrast: 60, brightness: -10);
          filteredImage = _applyVignetteEffect(filteredImage, 0.3);
          break;
        case 'warm':
          filteredImage = img.adjustColor(filteredImage, saturation: 20);
          filteredImage = _applyColorTemperature(filteredImage, 30);
          break;
        case 'cool':
          filteredImage = img.adjustColor(filteredImage, saturation: 20);
          filteredImage = _applyColorTemperature(filteredImage, -30);
          break;
        case 'bw_high_contrast':
          filteredImage = img.grayscale(filteredImage);
          filteredImage = img.adjustColor(filteredImage, contrast: 40);
          break;
        case 'bw_classic':
          filteredImage = img.grayscale(filteredImage);
          filteredImage = img.adjustColor(filteredImage, brightness: 15);
          break;
        case 'vintage':
          filteredImage =
              img.adjustColor(filteredImage, saturation: -20, brightness: 15);
          filteredImage = _applySepia(filteredImage);
          filteredImage = _applyVignetteEffect(filteredImage, 0.4);
          break;
        case 'cinematic':
          filteredImage =
              img.adjustColor(filteredImage, contrast: 35, saturation: 25);
          filteredImage = _applyColorGrading(filteredImage, 10, 5, -5);
          break;
        case 'portrait':
          filteredImage =
              img.adjustColor(filteredImage, saturation: 15, brightness: 8);
          filteredImage = _applySkinSoftening(filteredImage);
          break;
        case 'dramatic_bw':
          filteredImage = img.grayscale(filteredImage);
          filteredImage =
              img.adjustColor(filteredImage, contrast: 50, brightness: -5);
          break;
      }

      final resultBytes =
          Uint8List.fromList(img.encodeJpg(filteredImage, quality: 95));
      _pushHistory(resultBytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        editedBytes: resultBytes,
        appliedFilterId: filterId,
        message: 'Filter applied successfully!',
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Failed to apply filter: ${e.toString()}',
        isProcessing: false,
      ));
    }
  }

  img.Image _applyVignetteEffect(img.Image image, double strength) {
    final centerX = image.width / 2;
    final centerY = image.height / 2;
    final maxDistance = math.sqrt(centerX * centerX + centerY * centerY);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final dx = x - centerX;
        final dy = y - centerY;
        final distance = math.sqrt(dx * dx + dy * dy);
        final vignette = 1.0 - (distance / maxDistance) * strength;

        final pixel = image.getPixel(x, y);
        final r = (pixel.r * vignette).clamp(0, 255).toInt();
        final g = (pixel.g * vignette).clamp(0, 255).toInt();
        final b = (pixel.b * vignette).clamp(0, 255).toInt();

        image.setPixelRgba(x, y, r, g, b, pixel.a);
      }
    }
    return image;
  }

  img.Image _applyColorTemperature(img.Image image, double temperature) {
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = (pixel.r + temperature).clamp(0, 255).toInt();
        final b = (pixel.b - temperature).clamp(0, 255).toInt();
        image.setPixelRgba(x, y, r, pixel.g, b, pixel.a);
      }
    }
    return image;
  }

  img.Image _applySepia(img.Image image) {
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = (pixel.r * 0.393 + pixel.g * 0.769 + pixel.b * 0.189)
            .clamp(0, 255)
            .toInt();
        final g = (pixel.r * 0.349 + pixel.g * 0.686 + pixel.b * 0.168)
            .clamp(0, 255)
            .toInt();
        final b = (pixel.r * 0.272 + pixel.g * 0.534 + pixel.b * 0.131)
            .clamp(0, 255)
            .toInt();
        image.setPixelRgba(x, y, r, g, b, pixel.a);
      }
    }
    return image;
  }

  img.Image _applyColorGrading(img.Image image, int red, int green, int blue) {
    return img.colorOffset(image, red: red, green: green, blue: blue);
  }

  img.Image _applySkinSoftening(img.Image image) {
    final blurred = img.gaussianBlur(image, radius: 2);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final original = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        // Detect skin tones (warm colors with red dominance)
        if (original.r > original.g &&
            original.r > original.b &&
            original.r > 100) {
          final r = (original.r * 0.7 + blur.r * 0.3).toInt();
          final g = (original.g * 0.7 + blur.g * 0.3).toInt();
          final b = (original.b * 0.7 + blur.b * 0.3).toInt();
          image.setPixelRgba(x, y, r, g, b, original.a);
        }
      }
    }
    return image;
  }

  // === AI ENHANCEMENTS ===
  Future<void> autoEnhance() async {
    try {
      if (state.originalBytes == null) return;

      emit(state.copyWith(status: EditorStatus.loading, isProcessing: true));

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) throw Exception('Unable to decode image');

      // Analyze image for automatic enhancements
      final analysis = _analyzeImage(originalImage);

      img.Image enhancedImage = img.copyResize(
        originalImage,
        width: originalImage.width,
        height: originalImage.height,
      );

      // Apply smart enhancements based on analysis
      if (analysis.isDark) {
        enhancedImage = img.adjustColor(enhancedImage, brightness: 25);
      }

      if (analysis.isLowContrast) {
        enhancedImage = img.adjustColor(enhancedImage, contrast: 30);
      }

      if (analysis.isLowSaturation) {
        enhancedImage = img.adjustColor(enhancedImage, saturation: 25);
      }

      // Always apply slight sharpening
      enhancedImage = _applySharpening(enhancedImage);

      final resultBytes =
          Uint8List.fromList(img.encodeJpg(enhancedImage, quality: 95));
      _pushHistory(resultBytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        editedBytes: resultBytes,
        message: 'Auto enhancement applied!',
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Auto enhancement failed: ${e.toString()}',
        isProcessing: false,
      ));
    }
  }

  Future<void> magicEdit() async {
    try {
      if (state.originalBytes == null) return;

      emit(state.copyWith(status: EditorStatus.loading, isProcessing: true));

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) throw Exception('Unable to decode image');

      img.Image magicImage = img.copyResize(
        originalImage,
        width: originalImage.width,
        height: originalImage.height,
      );

      // Apply multiple professional enhancements
      magicImage = img.adjustColor(magicImage,
          brightness: 12, contrast: 25, saturation: 20);
      magicImage = _applySharpening(magicImage);
      magicImage = _applyVignetteEffect(magicImage, 0.2);
      magicImage = _applyColorGrading(magicImage, 8, 5, -3);

      final resultBytes =
          Uint8List.fromList(img.encodeJpg(magicImage, quality: 95));
      _pushHistory(resultBytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        editedBytes: resultBytes,
        message: 'Magic edit applied! Your photo looks amazing!',
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Magic edit failed: ${e.toString()}',
        isProcessing: false,
      ));
    }
  }

  img.Image _applySharpening(img.Image image) {
    final blurred = img.gaussianBlur(image, radius: 1);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final original = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final r =
            (original.r + 0.8 * (original.r - blur.r)).clamp(0, 255).toInt();
        final g =
            (original.g + 0.8 * (original.g - blur.g)).clamp(0, 255).toInt();
        final b =
            (original.b + 0.8 * (original.b - blur.b)).clamp(0, 255).toInt();

        image.setPixelRgba(x, y, r, g, b, original.a);
      }
    }
    return image;
  }

  // === SPECIAL EFFECTS ===
  Future<void> applyBlurEffect(
      {double intensity = 0.5, bool isTiltShift = false}) async {
    try {
      if (state.originalBytes == null) return;

      emit(state.copyWith(status: EditorStatus.loading, isProcessing: true));

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) throw Exception('Unable to decode image');

      img.Image blurredImage = img.copyResize(
        originalImage,
        width: originalImage.width,
        height: originalImage.height,
      );

      if (isTiltShift) {
        blurredImage = _applyTiltShift(blurredImage, intensity);
      } else {
        final radius = (intensity.clamp(0.0, 1.0) * 20).toInt();
        blurredImage = img.gaussianBlur(blurredImage, radius: radius);
      }

      final resultBytes =
          Uint8List.fromList(img.encodeJpg(blurredImage, quality: 95));
      _pushHistory(resultBytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        editedBytes: resultBytes,
        message: 'Blur effect applied!',
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Blur effect failed: ${e.toString()}',
        isProcessing: false,
      ));
    }
  }

  img.Image _applyTiltShift(img.Image image, double intensity) {
    final blurred = img.gaussianBlur(image, radius: 10);
    final centerY = image.height / 2;
    final focusHeight = image.height * 0.2 * (1.0 - intensity.clamp(0.0, 1.0));

    for (int y = 0; y < image.height; y++) {
      final distanceFromCenter = (y - centerY).abs();
      double blurAmount = 0.0;

      if (distanceFromCenter > focusHeight) {
        blurAmount = ((distanceFromCenter - focusHeight) /
                (image.height / 2 - focusHeight))
            .clamp(0.0, 1.0);
      }

      for (int x = 0; x < image.width; x++) {
        final original = image.getPixel(x, y);
        final blur = blurred.getPixel(x, y);

        final r = (original.r * (1 - blurAmount) + blur.r * blurAmount).toInt();
        final g = (original.g * (1 - blurAmount) + blur.g * blurAmount).toInt();
        final b = (original.b * (1 - blurAmount) + blur.b * blurAmount).toInt();

        image.setPixelRgba(x, y, r, g, b, original.a);
      }
    }
    return image;
  }

  // === BACKGROUND METHODS ===
  Future<void> changeBackgroundColor(Color color) async {
    try {
      if (state.originalBytes == null) return;

      emit(state.copyWith(
        status: EditorStatus.processing,
        isProcessing: true,
        processingProgress: 0.1,
      ));

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) throw Exception('Unable to decode image');

      img.Image processedImage;

      // Check if image has transparency
      if (_hasTransparency(originalImage)) {
        // If image has transparency, fill transparent areas with the new color
        processedImage = _fillTransparentAreas(originalImage, color);
      } else {
        // If no transparency, apply color overlay effect
        processedImage = _applyColorOverlay(originalImage, color);
      }

      final resultBytes =
          Uint8List.fromList(img.encodeJpg(processedImage, quality: 95));
      _pushHistory(resultBytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        editedBytes: resultBytes,
        isProcessing: false,
        processingProgress: 1.0,
        backgroundColor: color,
        isBackgroundTransparent: false,
        message: 'Background color changed',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        isProcessing: false,
        message: 'Failed to change background color: ${e.toString()}',
      ));
    }
  }

  Future<void> applyBackgroundBlur(double intensity) async {
    try {
      if (state.originalBytes == null) return;

      emit(state.copyWith(
        status: EditorStatus.processing,
        isProcessing: true,
        processingProgress: 0.1,
      ));

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) throw Exception('Unable to decode image');

      img.Image processedImage;

      // Apply blur effect based on image type
      if (_hasTransparency(originalImage)) {
        processedImage = _blurBackgroundAreas(originalImage, intensity);
      } else {
        processedImage = _applyOverallBlur(originalImage, intensity);
      }

      final resultBytes =
          Uint8List.fromList(img.encodeJpg(processedImage, quality: 95));
      _pushHistory(resultBytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        editedBytes: resultBytes,
        isProcessing: false,
        processingProgress: 1.0,
        backgroundBlurIntensity: intensity,
        isBackgroundTransparent: false,
        message: 'Background blur applied',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        isProcessing: false,
        message: 'Failed to apply background blur: ${e.toString()}',
      ));
    }
  }

  Future<void> makeBackgroundTransparent() async {
    try {
      if (state.originalBytes == null) return;

      emit(state.copyWith(
        status: EditorStatus.processing,
        isProcessing: true,
        processingProgress: 0.1,
      ));

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) throw Exception('Unable to decode image');

      img.Image processedImage;

      if (_hasTransparency(originalImage)) {
        // Already has transparency, just enhance it
        processedImage = _enhanceTransparency(originalImage);
      } else {
        // Create transparency by detecting and removing background
        processedImage = _removeBackground(originalImage);
      }

      // Use PNG format to preserve transparency
      final resultBytes = Uint8List.fromList(img.encodePng(processedImage));
      _pushHistory(resultBytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        editedBytes: resultBytes,
        isProcessing: false,
        processingProgress: 1.0,
        isBackgroundTransparent: true,
        backgroundColor: null,
        message: _hasTransparency(originalImage)
            ? 'Transparency enhanced'
            : 'Background removal applied',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        isProcessing: false,
        message: 'Failed to apply transparency: ${e.toString()}',
      ));
    }
  }

  void removeBackground() {
    try {
      if (state.originalBytes == null) return;

      // Reset to original image to remove background effects
      _pushHistory(state.originalBytes!);

      emit(state.copyWith(
        editedBytes: state.originalBytes,
        backgroundColor: null,
        backgroundBlurIntensity: 0.0,
        isBackgroundTransparent: false,
        status: EditorStatus.success,
        message: 'Background effects removed - restored to original',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Failed to remove background: ${e.toString()}',
      ));
    }
  }

  // Helper method to check if image has transparency
  bool _hasTransparency(img.Image image) {
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        if (pixel.a < 255) {
          return true;
        }
      }
    }
    return false;
  }

// Fill transparent areas with solid color (for PNG images with transparency)
  img.Image _fillTransparentAreas(img.Image image, Color color) {
    final processedImage = img.Image.from(image);

    for (int y = 0; y < processedImage.height; y++) {
      for (int x = 0; x < processedImage.width; x++) {
        final pixel = processedImage.getPixel(x, y);

        // If pixel is transparent or semi-transparent, replace with background color
        if (pixel.a < 250) {
          processedImage.setPixelRgba(
              x, y, color.red, color.green, color.blue, 255);
        }
      }
    }

    return processedImage;
  }

// Apply color overlay for images without transparency
  img.Image _applyColorOverlay(img.Image image, Color color) {
    final processedImage = img.copyResize(
      image,
      width: image.width,
      height: image.height,
    );

    // Create a color overlay effect
    final overlayStrength = 0.3;

    for (int y = 0; y < processedImage.height; y++) {
      for (int x = 0; x < processedImage.width; x++) {
        final pixel = processedImage.getPixel(x, y);
        final red = pixel.r.toInt();
        final green = pixel.g.toInt();
        final blue = pixel.b.toInt();
        final alpha = pixel.a.toInt();

        // Blend with background color
        final r = (red * (1 - overlayStrength) + color.red * overlayStrength)
            .clamp(0, 255)
            .toInt();
        final g =
            (green * (1 - overlayStrength) + color.green * overlayStrength)
                .clamp(0, 255)
                .toInt();
        final b = (blue * (1 - overlayStrength) + color.blue * overlayStrength)
            .clamp(0, 255)
            .toInt();

        processedImage.setPixelRgba(x, y, r, g, b, alpha);
      }
    }

    return processedImage;
  }

// Blur only the background areas (for transparent images)
  img.Image _blurBackgroundAreas(img.Image image, double intensity) {
    final processedImage = img.Image.from(image);
    final blurredImage =
        img.gaussianBlur(processedImage, radius: (intensity * 15).toInt());

    for (int y = 0; y < processedImage.height; y++) {
      for (int x = 0; x < processedImage.width; x++) {
        final originalPixel = processedImage.getPixel(x, y);
        final blurPixel = blurredImage.getPixel(x, y);

        // Only apply blur to transparent/semi-transparent areas (background)
        if (originalPixel.a < 200) {
          processedImage.setPixel(x, y, blurPixel);
        }
      }
    }

    return processedImage;
  }

// Apply blur to entire image (for opaque images)
  img.Image _applyOverallBlur(img.Image image, double intensity) {
    final radius = (intensity.clamp(0.0, 1.0) * 20).toInt();
    return img.gaussianBlur(image, radius: radius);
  }

// Enhance existing transparency
  img.Image _enhanceTransparency(img.Image image) {
    final processedImage = img.Image.from(image);

    for (int y = 0; y < processedImage.height; y++) {
      for (int x = 0; x < processedImage.width; x++) {
        final pixel = processedImage.getPixel(x, y);

        // Make semi-transparent areas more transparent
        if (pixel.a < 200) {
          final newAlpha = (pixel.a * 0.7).clamp(0, 255).toInt();
          processedImage.setPixelRgba(x, y, pixel.r.toInt(), pixel.g.toInt(),
              pixel.b.toInt(), newAlpha);
        }
      }
    }

    return processedImage;
  }

// Remove background from opaque images (basic implementation)
  img.Image _removeBackground(img.Image image) {
    final processedImage = img.Image.from(image);

    // Simple background removal based on edge detection and color analysis
    // This is a basic implementation - real background removal would be more complex

    // First, detect edges to identify main subject
    final edges = _detectEdges(image);

    for (int y = 0; y < processedImage.height; y++) {
      for (int x = 0; x < processedImage.width; x++) {
        final pixel = processedImage.getPixel(x, y);

        // If it's likely background (based on simple heuristics), make it transparent
        if (_isLikelyBackground(pixel, edges, x, y)) {
          processedImage.setPixelRgba(
              x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 50);
        }
      }
    }

    return processedImage;
  }

// Simple edge detection
  List<List<bool>> _detectEdges(img.Image image) {
    final edges =
        List.generate(image.height, (_) => List.filled(image.width, false));
    final grayscale = img.grayscale(img.Image.from(image));

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final current = grayscale.getPixel(x, y).luminance;
        final right = grayscale.getPixel(x + 1, y).luminance;
        final bottom = grayscale.getPixel(x, y + 1).luminance;

        // Simple edge detection: significant luminance change
        if ((current - right).abs() > 30 || (current - bottom).abs() > 30) {
          edges[y][x] = true;
        }
      }
    }

    return edges;
  }

// Simple background detection
  bool _isLikelyBackground(
      img.Pixel pixel, List<List<bool>> edges, int x, int y) {
    final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);

    // Likely background if:
    // 1. Very bright or very dark areas
    // 2. Not near edges
    // 3. Has uniform color characteristics

    final isEdge = edges[y][x];
    final isVeryBright = brightness > 200;
    final isVeryDark = brightness < 50;
    final hasLowSaturation = _getSaturation(pixel) < 0.2;

    return !isEdge && (isVeryBright || isVeryDark || hasLowSaturation);
  }

  double _getSaturation(img.Pixel pixel) {
    final maxVal = [pixel.r, pixel.g, pixel.b].reduce((a, b) => a > b ? a : b);
    final minVal = [pixel.r, pixel.g, pixel.b].reduce((a, b) => a < b ? a : b);
    return maxVal == 0 ? 0 : (maxVal - minVal) / maxVal;
  }

  // === IMAGE ANALYSIS ===
  _ImageAnalysis _analyzeImage(img.Image image) {
    double totalBrightness = 0;
    int minBrightness = 255;
    int maxBrightness = 0;
    double totalSaturation = 0;

    int sampleCount = 0;

    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        final brightness =
            (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);

        totalBrightness += brightness;
        minBrightness = math.min(minBrightness, brightness.toInt());
        maxBrightness = math.max(maxBrightness, brightness.toInt());

        // Simple saturation calculation
        final maxColor = math.max(pixel.r, math.max(pixel.g, pixel.b));
        final minColor = math.min(pixel.r, math.min(pixel.g, pixel.b));
        final saturation = maxColor == 0 ? 0 : (maxColor - minColor) / maxColor;
        totalSaturation += saturation;

        sampleCount++;
      }
    }

    final avgBrightness = totalBrightness / sampleCount / 255;
    final avgSaturation = totalSaturation / sampleCount;
    final contrastRange = (maxBrightness - minBrightness) / 255.0;

    return _ImageAnalysis(
      isDark: avgBrightness < 0.4,
      isLowContrast: contrastRange < 0.3,
      isLowSaturation: avgSaturation < 0.2,
      averageBrightness: avgBrightness,
    );
  }

  // === UTILITY METHODS ===
  void setOverlay(String? overlay) {
    emit(state.copyWith(overlay: overlay));
  }

  void reset() {
    if (state.originalBytes != null) {
      _pushHistory(state.originalBytes!);
      emit(state.copyWith(
        editedBytes: state.originalBytes,
        brightness: 0.0,
        contrast: 0.0,
        saturation: 0.0,
        exposure: 0.0,
        warmth: 0.0,
        highlights: 0.0,
        shadows: 0.0,
        sharpness: 0.0,
        vignette: 0.0,
        blur: 0.0,
        appliedFilterId: null,
        overlay: null,
        backgroundColor: null,
        backgroundBlurIntensity: 0.0,
        isBackgroundTransparent: false,
        status: EditorStatus.success,
        message: 'Reset to original',
      ));
    }
  }

  Future<void> saveImage() async {
    try {
      if (state.editedBytes == null) return;

      emit(state.copyWith(status: EditorStatus.loading));

      // For web demo, we'll just show success message
      emit(state.copyWith(
        status: EditorStatus.success,
        message: 'Image enhanced successfully! (Use screenshot to save)',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Failed to process image: ${e.toString()}',
      ));
    }
  }

  void clearAll() {
    _history.clear();
    _redoStack.clear();
    _historyIndex = -1;
    emit(const EditorState());
  }

  Future<void> textToEdit(String prompt) async {
    try {
      if (state.originalBytes == null) return;

      emit(state.copyWith(status: EditorStatus.loading, isProcessing: true));

      // Simulate AI processing based on text prompt
      await Future.delayed(const Duration(seconds: 2));

      final img.Image? originalImage = img.decodeImage(state.originalBytes!);
      if (originalImage == null) throw Exception('Unable to decode image');

      img.Image processedImage = img.copyResize(
        originalImage,
        width: originalImage.width,
        height: originalImage.height,
      );

      // Apply effects based on common prompts
      final lowerPrompt = prompt.toLowerCase();

      if (lowerPrompt.contains('bright') || lowerPrompt.contains('light')) {
        processedImage = img.adjustColor(processedImage, brightness: 30);
      }

      if (lowerPrompt.contains('contrast') ||
          lowerPrompt.contains('dramatic')) {
        processedImage = img.adjustColor(processedImage, contrast: 40);
      }

      if (lowerPrompt.contains('vibrant') || lowerPrompt.contains('color')) {
        processedImage = img.adjustColor(processedImage, saturation: 35);
      }

      if (lowerPrompt.contains('warm') || lowerPrompt.contains('sunset')) {
        processedImage = _applyColorTemperature(processedImage, 25);
      }

      if (lowerPrompt.contains('cool') || lowerPrompt.contains('blue')) {
        processedImage = _applyColorTemperature(processedImage, -25);
      }

      if (lowerPrompt.contains('vintage') || lowerPrompt.contains('old')) {
        processedImage = _applySepia(processedImage);
      }

      if (lowerPrompt.contains('sharp') || lowerPrompt.contains('clear')) {
        processedImage = _applySharpening(processedImage);
      }

      final resultBytes =
          Uint8List.fromList(img.encodeJpg(processedImage, quality: 95));
      _pushHistory(resultBytes);

      emit(state.copyWith(
        status: EditorStatus.success,
        editedBytes: resultBytes,
        message: 'Text edit applied: "$prompt"',
        isProcessing: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: EditorStatus.error,
        message: 'Text edit failed: ${e.toString()}',
        isProcessing: false,
      ));
    }
  }
}
