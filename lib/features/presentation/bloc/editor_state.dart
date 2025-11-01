import 'dart:typed_data';

enum EditorStatus {
  initial,
  loading,
  ready,
  success,
  error,
}

class EditorState {
  final EditorStatus status;
  final Uint8List? originalBytes;
  final Uint8List? editedBytes;
  final String? message;
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
  final String? appliedFilterId;
  final String? overlay;
  final bool canUndo;
  final bool canRedo;
  final String? fileName;
  final int? fileSize;
  final bool isProcessing;
  final double processingProgress;

  const EditorState({
    this.status = EditorStatus.initial,
    this.originalBytes,
    this.editedBytes,
    this.message,
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
    this.canUndo = false,
    this.canRedo = false,
    this.fileName,
    this.fileSize,
    this.isProcessing = false,
    this.processingProgress = 0.0,
  });

  EditorState copyWith({
    EditorStatus? status,
    Uint8List? originalBytes,
    Uint8List? editedBytes,
    String? message,
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
    bool? canUndo,
    bool? canRedo,
    String? fileName,
    int? fileSize,
    bool? isProcessing,
    double? processingProgress,
  }) {
    return EditorState(
      status: status ?? this.status,
      originalBytes: originalBytes ?? this.originalBytes,
      editedBytes: editedBytes ?? this.editedBytes,
      message: message ?? this.message,
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
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      isProcessing: isProcessing ?? this.isProcessing,
      processingProgress: processingProgress ?? this.processingProgress,
    );
  }
}
