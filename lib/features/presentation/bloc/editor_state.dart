import 'dart:typed_data';

enum EditorStatus { initial, loading, ready, error }

class EditorState {
  final EditorStatus status;
  final Uint8List? originalBytes;
  final Uint8List? editedBytes;
  final double brightness;
  final double contrast;
  final double saturation;
  final String? message;
  final String? overlay; // e.g., 'festival_frame', 'forest_border'
  final String? appliedFilterId; // e.g., 'gedeo_warm'

  const EditorState({
    this.status = EditorStatus.initial,
    this.originalBytes,
    this.editedBytes,
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.message,
    this.overlay,
    this.appliedFilterId,
  });

  EditorState copyWith({
    EditorStatus? status,
    Uint8List? originalBytes,
    Uint8List? editedBytes,
    double? brightness,
    double? contrast,
    double? saturation,
    String? message,
    bool clearMessage = false,
    String? overlay,
    String? appliedFilterId,
  }) {
    return EditorState(
      status: status ?? this.status,
      originalBytes: originalBytes ?? this.originalBytes,
      editedBytes: editedBytes ?? this.editedBytes,
      brightness: brightness ?? this.brightness,
      contrast: contrast ?? this.contrast,
      saturation: saturation ?? this.saturation,
      message: clearMessage ? null : (message ?? this.message),
      overlay: overlay ?? this.overlay,
      appliedFilterId: appliedFilterId ?? this.appliedFilterId,
    );
  }
}
