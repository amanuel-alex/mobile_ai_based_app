import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class EditorState extends Equatable {
  final Uint8List? originalBytes;
  final Uint8List? editedBytes;
  final EditorStatus status;
  final String? message;
  final bool isProcessing;
  final double processingProgress;
  final bool canUndo;
  final bool canRedo;

  // Adjustment properties
  final double brightness;
  final double contrast;
  final double saturation;
  final double exposure;
  final double warmth;
  final double highlights;
  final double shadows;
  final double sharpness;
  final double vignette;
  final double blur;

  // Filter properties
  final String? appliedFilterId;

  // Overlay properties
  final String? overlay;

  // File properties
  final String? fileName;
  final int? fileSize;

  // Background properties
  final Color? backgroundColor;
  final double backgroundBlurIntensity;
  final bool isBackgroundTransparent;

  const EditorState({
    this.originalBytes,
    this.editedBytes,
    this.status = EditorStatus.initial,
    this.message,
    this.isProcessing = false,
    this.processingProgress = 0.0,
    this.canUndo = false,
    this.canRedo = false,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.exposure = 0.0,
    this.warmth = 0.0,
    this.highlights = 0.0,
    this.shadows = 0.0,
    this.sharpness = 0.0,
    this.vignette = 0.0,
    this.blur = 0.0,
    this.appliedFilterId,
    this.overlay,
    this.fileName,
    this.fileSize,
    this.backgroundColor,
    this.backgroundBlurIntensity = 0.0,
    this.isBackgroundTransparent = false,
  });

  EditorState copyWith({
    Uint8List? originalBytes,
    Uint8List? editedBytes,
    EditorStatus? status,
    String? message,
    bool? isProcessing,
    double? processingProgress,
    bool? canUndo,
    bool? canRedo,
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
    String? appliedFilterId,
    String? overlay,
    String? fileName,
    int? fileSize,
    Color? backgroundColor,
    double? backgroundBlurIntensity,
    bool? isBackgroundTransparent,
  }) {
    return EditorState(
      originalBytes: originalBytes ?? this.originalBytes,
      editedBytes: editedBytes ?? this.editedBytes,
      status: status ?? this.status,
      message: message ?? this.message,
      isProcessing: isProcessing ?? this.isProcessing,
      processingProgress: processingProgress ?? this.processingProgress,
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      exposure: exposure ?? this.exposure,
      warmth: warmth ?? this.warmth,
      highlights: highlights ?? this.highlights,
      shadows: shadows ?? this.shadows,
      sharpness: sharpness ?? this.sharpness,
      vignette: vignette ?? this.vignette,
      blur: blur ?? this.blur,
      appliedFilterId: appliedFilterId ?? this.appliedFilterId,
      overlay: overlay ?? this.overlay,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundBlurIntensity:
          backgroundBlurIntensity ?? this.backgroundBlurIntensity,
      isBackgroundTransparent:
          isBackgroundTransparent ?? this.isBackgroundTransparent,
    );
  }

  @override
  List<Object?> get props => [
        originalBytes,
        editedBytes,
        status,
        message,
        isProcessing,
        processingProgress,
        canUndo,
        canRedo,
        brightness,
        contrast,
        saturation,
        exposure,
        warmth,
        highlights,
        shadows,
        sharpness,
        vignette,
        blur,
        appliedFilterId,
        overlay,
        fileName,
        fileSize,
        backgroundColor,
        backgroundBlurIntensity,
        isBackgroundTransparent,
      ];
}

enum EditorStatus {
  initial,
  loading,
  processing,
  success,
  error,
}
