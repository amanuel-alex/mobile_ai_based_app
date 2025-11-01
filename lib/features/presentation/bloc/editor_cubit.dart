import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'editor_state.dart';

enum ExportFormat { jpeg, png, webp }

class EditorCubit extends Cubit<EditorState> {
  EditorCubit() : super(const EditorState());

  final ImagePicker _picker = ImagePicker();

  // internal undo/redo & presets (kept in memory)
  final List<Uint8List> _history = [];
  int _historyIndex = -1;
  final List<Map<String, dynamic>> _presets = [];

  // --- helpers -------------------------------------------------------------
  void _pushHistory(Uint8List bytes) {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(bytes);
    _historyIndex = _history.length - 1;
  }

  void undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      final b = _history[_historyIndex];
      emit(state.copyWith(editedBytes: b, status: EditorStatus.ready));
    }
  }

  void redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      final b = _history[_historyIndex];
      emit(state.copyWith(editedBytes: b, status: EditorStatus.ready));
    }
  }

  void savePreset(String id, Map<String, dynamic> config) {
    _presets.removeWhere((p) => p['id'] == id);
    _presets.add({'id': id, 'config': config});
  }

  List<Map<String, dynamic>> listPresets() => List.unmodifiable(_presets);

  Future<void> applyPreset(String id) async {
    final p = _presets.firstWhere((e) => e['id'] == id, orElse: () => {});
    if (p.isEmpty) return;
    final cfg = p['config'] as Map<String, dynamic>;
    if (cfg.containsKey('filterId'))
      await applyFilter(cfg['filterId'] as String);
    if (cfg.containsKey('brightness') ||
        cfg.containsKey('contrast') ||
        cfg.containsKey('saturation')) {
      updateAdjustments(
        brightness: cfg['brightness']?.toDouble(),
        contrast: cfg['contrast']?.toDouble(),
        saturation: cfg['saturation']?.toDouble(),
      );
      await applyAdjustments();
    }
    if (cfg.containsKey('vignette'))
      await lensVignette(cfg['vignette'] as double);
  }

  Future<void> pickImage() async {
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        emit(state.copyWith(status: EditorStatus.initial));
        return;
      }
      final rawBytes = await file.readAsBytes();
      final img.Image? decoded = img.decodeImage(rawBytes);
      if (decoded == null) throw Exception('Unable to decode selected image');
      final normalized = Uint8List.fromList(
        img.encodeJpg(decoded, quality: 95),
      );
      _pushHistory(normalized);
      emit(
        state.copyWith(
          status: EditorStatus.ready,
          originalBytes: normalized,
          editedBytes: normalized,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> pickImageFromCamera() async {
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final XFile? file = await _picker.pickImage(source: ImageSource.camera);
      if (file == null) {
        emit(state.copyWith(status: EditorStatus.initial));
        return;
      }
      final rawBytes = await file.readAsBytes();
      final img.Image? decoded = img.decodeImage(rawBytes);
      if (decoded == null) throw Exception('Unable to decode captured image');
      final normalized = Uint8List.fromList(
        img.encodeJpg(decoded, quality: 95),
      );
      _pushHistory(normalized);
      emit(
        state.copyWith(
          status: EditorStatus.ready,
          originalBytes: normalized,
          editedBytes: normalized,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  void setEdited(Uint8List bytes) {
    _pushHistory(bytes);
    emit(state.copyWith(editedBytes: bytes, status: EditorStatus.ready));
  }

  void updateAdjustments({
    double? brightness,
    double? contrast,
    double? saturation,
  }) {
    emit(
      state.copyWith(
        brightness: brightness ?? state.brightness,
        contrast: contrast ?? state.contrast,
        saturation: saturation ?? state.saturation,
      ),
    );
  }

  Future<void> applyAdjustments() async {
    try {
      if (state.editedBytes == null) return;
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? decoded = img.decodeImage(state.editedBytes!);
      if (decoded == null) throw Exception('Unable to decode image');
      final adj = img.adjustColor(
        decoded,
        brightness: state.brightness,
        contrast: state.contrast,
        saturation: state.saturation,
      );
      final out = Uint8List.fromList(img.encodeJpg(adj, quality: 95));
      _pushHistory(out);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: out));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  // ----------------- Filters / Transformations (local approximations) -----------------
  Future<void> applyFilter(String filterId) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? base = img.decodeImage(state.editedBytes!);
      if (base == null) throw Exception('Unable to decode image');
      img.Image out = img.copyResize(
        base,
        width: base.width,
        height: base.height,
      );

      switch (filterId) {
        case 'gedeo_warm':
          out = img.adjustColor(out, saturation: 0.2, brightness: 0.05);
          out = img.colorOffset(out, red: 10);
          break;
        case 'forest_green':
          out = img.adjustColor(out, gamma: 0.95, saturation: 0.15);
          out = img.colorOffset(out, green: 12);
          break;
        case 'festival_pop':
          out = img.adjustColor(
            out,
            contrast: 0.2,
            saturation: 0.35,
            brightness: 0.05,
          );
          break;
        case 'bw_classic':
          out = img.grayscale(out);
          out = img.adjustColor(out, contrast: 0.15);
          break;
        default:
          break;
      }
      final result = Uint8List.fromList(img.encodeJpg(out, quality: 95));
      _pushHistory(result);
      emit(
        state.copyWith(
          status: EditorStatus.ready,
          editedBytes: result,
          appliedFilterId: filterId,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> tiltShift({
    double center = 0.5,
    double span = 0.3,
    bool horizontal = true,
  }) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? base = img.decodeImage(state.editedBytes!);
      if (base == null) throw Exception('Unable to decode image');
      final img.Image blurred = img.gaussianBlur(
        img.copyResize(base, width: base.width, height: base.height),
        radius: 8,
      );

      final w = base.width;
      final h = base.height;
      final img.Image out = img.copyResize(base, width: w, height: h);
      final double half = (span.clamp(0.05, 0.9)) / 2.0;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          double t = horizontal ? (y / (h - 1)) : (x / (w - 1));
          double dist = (t - center).abs();
          double m = ((dist - half) / (0.5 - half)).clamp(0.0, 1.0);
          final img.Pixel p0 = base.getPixel(x, y);
          final img.Pixel p1 = blurred.getPixel(x, y);
          int r = (p0.r * (1 - m) + p1.r * m).round();
          int g = (p0.g * (1 - m) + p1.g * m).round();
          int b = (p0.b * (1 - m) + p1.b * m).round();
          out.setPixelRgba(x, y, r, g, b, 255);
        }
      }
      final result = Uint8List.fromList(img.encodeJpg(out, quality: 95));
      _pushHistory(result);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> colorSplash({
    required double hue,
    double tolerance = 0.08,
  }) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? base = img.decodeImage(state.editedBytes!);
      if (base == null) throw Exception('Unable to decode image');
      final w = base.width, h = base.height;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final img.Pixel p = base.getPixel(x, y);
          double r = p.r / 255.0;
          double g = p.g / 255.0;
          double b = p.b / 255.0;
          final double maxv = [r, g, b].reduce((a, b) => a > b ? a : b);
          final double minv = [r, g, b].reduce((a, b) => a < b ? a : b);
          final double d = maxv - minv;
          double hDeg = 0.0;
          if (d == 0) {
            hDeg = 0;
          } else if (maxv == r) {
            hDeg = 60 * (((g - b) / d) % 6);
          } else if (maxv == g) {
            hDeg = 60 * (((b - r) / d) + 2);
          } else {
            hDeg = 60 * (((r - g) / d) + 4);
          }
          if (hDeg < 0) hDeg += 360;
          double hNorm = hDeg / 360.0;
          double diff = (hNorm - hue).abs();
          diff = diff > 0.5 ? 1.0 - diff : diff;
          if (diff > tolerance) {
            int gray = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round();
            base.setPixelRgba(x, y, gray, gray, gray, p.a);
          }
        }
      }
      final result = Uint8List.fromList(img.encodeJpg(base, quality: 95));
      _pushHistory(result);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> doubleExposure(
    Uint8List otherBytes, {
    double opacity = 0.5,
  }) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? base = img.decodeImage(state.editedBytes!);
      final img.Image? other = img.decodeImage(otherBytes);
      if (base == null || other == null)
        throw Exception('Unable to decode image');
      final img.Image otherResized = img.copyResize(
        other,
        width: base.width,
        height: base.height,
      );
      final w = base.width, h = base.height;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final img.Pixel p0 = base.getPixel(x, y);
          final img.Pixel p1 = otherResized.getPixel(x, y);
          int r = ((p0.r * (1 - opacity) + p1.r * opacity)).round();
          int g = ((p0.g * (1 - opacity) + p1.g * opacity)).round();
          int b = ((p0.b * (1 - opacity) + p1.b * opacity)).round();
          base.setPixelRgba(x, y, r, g, b, p0.a);
        }
      }
      final result = Uint8List.fromList(img.encodeJpg(base, quality: 95));
      _pushHistory(result);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> lensVignette(double strength) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? base = img.decodeImage(state.editedBytes!);
      if (base == null) throw Exception('Unable to decode image');

      final double w = base.width.toDouble();
      final double h = base.height.toDouble();
      final double cx = w / 2.0, cy = h / 2.0;
      final double maxR = math.sqrt(w * w + h * h) / 2.0;

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final dx = x - cx;
          final dy = y - cy;
          final d = math.sqrt(dx * dx + dy * dy);
          final v = (d / maxR).clamp(0.0, 1.0);
          final m = (1.0 - v * strength.clamp(0.0, 1.0)).clamp(0.0, 1.0);
          final img.Pixel p = base.getPixel(x, y);
          final r = (p.r * m).round();
          final g = (p.g * m).round();
          final b = (p.b * m).round();
          final a = p.a;
          base.setPixelRgba(x, y, r, g, b, a);
        }
      }

      final out = Uint8List.fromList(img.encodeJpg(base, quality: 95));
      _pushHistory(out);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: out));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> lensDistortion(double amount) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? src = img.decodeImage(state.editedBytes!);
      if (src == null) throw Exception('Unable to decode image');

      final int w = src.width;
      final int h = src.height;
      final img.Image dst = img.Image(width: w, height: h);
      final double cx = (w - 1) / 2.0;
      final double cy = (h - 1) / 2.0;
      final double k = amount;

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final nx = (x - cx) / cx;
          final ny = (y - cy) / cy;
          final r2 = nx * nx + ny * ny;
          final factor = 1 + k * r2;
          final sx = cx + nx * factor * cx;
          final sy = cy + ny * factor * cy;
          final ix = sx.round();
          final iy = sy.round();
          if (ix >= 0 && ix < w && iy >= 0 && iy < h) {
            final img.Pixel sp = src.getPixel(ix, iy);
            dst.setPixelRgba(x, y, sp.r, sp.g, sp.b, sp.a);
          } else {
            dst.setPixelRgba(x, y, 0, 0, 0, 255);
          }
        }
      }

      final out = Uint8List.fromList(img.encodeJpg(dst, quality: 95));
      _pushHistory(out);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: out));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> fixChromaticAberration(double shiftPx) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? src = img.decodeImage(state.editedBytes!);
      if (src == null) throw Exception('Unable to decode image');
      final int w = src.width, h = src.height;
      final img.Image out = img.Image(width: w, height: h);

      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final int xr = (x + shiftPx).round().clamp(0, w - 1);
          final int xb = (x - shiftPx).round().clamp(0, w - 1);
          final img.Pixel pr = src.getPixel(xr, y);
          final img.Pixel pg = src.getPixel(x, y);
          final img.Pixel pb = src.getPixel(xb, y);
          out.setPixelRgba(x, y, pr.r, pg.g, pb.b, pg.a);
        }
      }

      final result = Uint8List.fromList(img.encodeJpg(out, quality: 95));
      _pushHistory(result);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  // ----------------- Background / Inpaint (local + external hooks) -----------------
  Future<void> removeBackgroundAuto({
    Uint8List? backgroundBytes,
    double threshold = 60.0,
  }) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? src = img.decodeImage(state.editedBytes!);
      if (src == null) throw Exception('Unable to decode image');
      final int w = src.width, h = src.height;

      img.Pixel c0 = src.getPixel(0, 0);
      img.Pixel c1 = src.getPixel(w - 1, 0);
      img.Pixel c2 = src.getPixel(0, h - 1);
      img.Pixel c3 = src.getPixel(w - 1, h - 1);
      final int sr = ((c0.r + c1.r + c2.r + c3.r) ~/ 4);
      final int sg = ((c0.g + c1.g + c2.g + c3.g) ~/ 4);
      final int sb = ((c0.b + c1.b + c2.b + c3.b) ~/ 4);

      final img.Image out = img.Image(
        width: w,
        height: h,
        channels: img.Channels.rgba,
      );
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final img.Pixel p = src.getPixel(x, y);
          final double dist = math.sqrt(
            math.pow(p.r - sr, 2) +
                math.pow(p.g - sg, 2) +
                math.pow(p.b - sb, 2),
          );
          if (dist < threshold) {
            out.setPixelRgba(x, y, p.r, p.g, p.b, 0);
          } else {
            out.setPixelRgba(x, y, p.r, p.g, p.b, p.a);
          }
        }
      }

      img.Image finalImg = out;
      if (backgroundBytes != null) {
        final img.Image? bg = img.decodeImage(backgroundBytes);
        if (bg == null) throw Exception('Invalid background image');
        final img.Image bgRes = img.copyResize(bg, width: w, height: h);
        finalImg = _compositeForegroundOverBackground(out, bgRes);
      }

      final result = finalImg.hasAlpha
          ? Uint8List.fromList(img.encodePng(finalImg))
          : Uint8List.fromList(img.encodeJpg(finalImg, quality: 95));
      _pushHistory(result);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> removeBackgroundWithApi(
    Future<Uint8List> Function(Uint8List) apiRemove, {
    Uint8List? backgroundBytes,
  }) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final Uint8List cutoutPng = await apiRemove(state.editedBytes!);
      final img.Image? fg = img.decodePng(cutoutPng);
      if (fg == null) throw Exception('API returned invalid PNG');

      img.Image out;
      if (backgroundBytes != null) {
        final img.Image? bg = img.decodeImage(backgroundBytes);
        if (bg == null) throw Exception('Background invalid');
        final img.Image bgRes = img.copyResize(
          bg,
          width: fg.width,
          height: fg.height,
        );
        out = _compositeForegroundOverBackground(fg, bgRes);
      } else {
        out = fg;
      }

      final result = out.hasAlpha
          ? Uint8List.fromList(img.encodePng(out))
          : Uint8List.fromList(img.encodeJpg(out, quality: 95));
      _pushHistory(result);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  img.Image _compositeForegroundOverBackground(img.Image fg, img.Image bg) {
    final img.Image out = img.copyResize(
      bg,
      width: fg.width,
      height: fg.height,
    );
    for (int y = 0; y < fg.height; y++) {
      for (int x = 0; x < fg.width; x++) {
        final img.Pixel p = fg.getPixel(x, y);
        final int alpha = p.a;
        if (alpha == 255) {
          out.setPixelRgba(x, y, p.r, p.g, p.b, 255);
        } else if (alpha > 0) {
          final img.Pixel bp = out.getPixel(x, y);
          final double a = alpha / 255.0;
          final int r = (p.r * a + bp.r * (1 - a)).round();
          final int g = (p.g * a + bp.g * (1 - a)).round();
          final int b = (p.b * a + bp.b * (1 - a)).round();
          out.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    }
    return out;
  }

  Future<void> removeObjectLocal(
    Uint8List maskBytes, {
    int maxRadius = 8,
  }) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? src = img.decodeImage(state.editedBytes!);
      final img.Image? maskImg = img.decodeImage(maskBytes);
      if (src == null || maskImg == null)
        throw Exception('Invalid image or mask');
      final int w = src.width, h = src.height;
      final img.Image mask = img.copyResize(maskImg, width: w, height: h);
      final List<List<bool>> masked = List.generate(
        h,
        (_) => List.filled(w, false),
      );
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final img.Pixel m = mask.getPixel(x, y);
          final int mval = ((m.r + m.g + m.b) ~/ 3);
          masked[y][x] = mval > 128;
        }
      }

      final img.Image out = img.copyResize(src, width: w, height: h);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          if (!masked[y][x]) continue;
          bool filled = false;
          for (int r = 1; r <= maxRadius && !filled; r++) {
            int count = 0;
            num sr = 0, sg = 0, sb = 0;
            final int xmin = math.max(0, x - r);
            final int xmax = math.min(w - 1, x + r);
            final int ymin = math.max(0, y - r);
            final int ymax = math.min(h - 1, y + r);
            for (int yy = ymin; yy <= ymax; yy++) {
              for (int xx = xmin; xx <= xmax; xx++) {
                if (yy != ymin && yy != ymax && xx != xmin && xx != xmax)
                  continue;
                if (!masked[yy][xx]) {
                  final img.Pixel p = src.getPixel(xx, yy);
                  sr += p.r;
                  sg += p.g;
                  sb += p.b;
                  count++;
                }
              }
            }
            if (count > 0) {
              final int rcol = (sr / count).round();
              final int gcol = (sg / count).round();
              final int bcol = (sb / count).round();
              out.setPixelRgba(x, y, rcol, gcol, bcol, 255);
              filled = true;
            }
          }
          if (!filled) {
            final img.Pixel p = src.getPixel(x, y);
            out.setPixelRgba(x, y, p.r, p.g, p.b, p.a);
          }
        }
      }

      final result = Uint8List.fromList(img.encodeJpg(out, quality: 95));
      _pushHistory(result);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> removeObjectWithApi(
    Future<Uint8List> Function(Uint8List, Uint8List) apiInpaint,
    Uint8List brushMaskBytes,
  ) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final Uint8List patched = await apiInpaint(
        state.editedBytes!,
        brushMaskBytes,
      );
      _pushHistory(patched);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: patched));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  // ----------------- AI-like local features ---------------------------------
  Future<void> photoToSketch({
    bool cartoon = false,
    int posterizeLevels = 6,
  }) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? src = img.decodeImage(state.editedBytes!);
      if (src == null) throw Exception('Unable to decode image');
      final int w = src.width, h = src.height;
      final img.Image gray = img.grayscale(src);
      final img.Image edges = img.copyResize(gray);
      final kernel = [
        [-1, -1, -1],
        [-1, 8, -1],
        [-1, -1, -1],
      ];
      for (int y = 1; y < h - 1; y++) {
        for (int x = 1; x < w - 1; x++) {
          int v = 0;
          for (int ky = -1; ky <= 1; ky++) {
            for (int kx = -1; kx <= 1; kx++) {
              final p = gray.getPixel(x + kx, y + ky);
              v += ((p.r) * kernel[ky + 1][kx + 1]);
            }
          }
          final c = (v.abs()).clamp(0, 255);
          edges.setPixelRgba(x, y, c, c, c, 255);
        }
      }

      if (cartoon) {
        final img.Image poster = img.copyResize(src);
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final p = poster.getPixel(x, y);
            int r =
                ((p.r / 255.0) * posterizeLevels).round() *
                (255 ~/ posterizeLevels);
            int g =
                ((p.g / 255.0) * posterizeLevels).round() *
                (255 ~/ posterizeLevels);
            int b =
                ((p.b / 255.0) * posterizeLevels).round() *
                (255 ~/ posterizeLevels);
            poster.setPixelRgba(
              x,
              y,
              r.clamp(0, 255),
              g.clamp(0, 255),
              b.clamp(0, 255),
              p.a,
            );
          }
        }
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            final e = edges.getPixel(x, y);
            if (e.r > 40) {
              poster.setPixelRgba(x, y, 0, 0, 0, 255);
            }
          }
        }
        final result = Uint8List.fromList(img.encodeJpg(poster, quality: 95));
        _pushHistory(result);
        emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
        return;
      }

      final img.Image sketch = img.copyResize(edges);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final p = sketch.getPixel(x, y);
          final int v = 255 - p.r;
          sketch.setPixelRgba(x, y, v, v, v, 255);
        }
      }
      final result = Uint8List.fromList(img.encodeJpg(sketch, quality: 95));
      _pushHistory(result);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> generateAvatar({
    Uint8List? backgroundBytes,
    int size = 512,
  }) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? src = img.decodeImage(state.editedBytes!);
      if (src == null) throw Exception('Unable to decode image');
      final int w = src.width, h = src.height;
      final int side = math.min(w, h);
      final int x0 = ((w - side) / 2).round();
      final int y0 = ((h - side) / 2).round();
      img.Image crop = img.copyCrop(
        src,
        x: x0,
        y: y0,
        width: side,
        height: side,
      );
      img.Image out = img.copyResize(crop, width: size, height: size);
      out = img.adjustColor(out, saturation: 0.2, contrast: 0.12);
      final img.Image circ = img.Image(
        width: size,
        height: size,
        channels: img.Channels.rgba,
      );
      final double cx = size / 2.0, cy = size / 2.0;
      final double r = size / 2.0;
      for (int y = 0; y < size; y++) {
        for (int x = 0; x < size; x++) {
          final dx = x - cx;
          final dy = y - cy;
          final d = math.sqrt(dx * dx + dy * dy);
          if (d <= r) {
            final p = out.getPixel(x, y);
            circ.setPixelRgba(x, y, p.r, p.g, p.b, 255);
          } else {
            circ.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
      }

      img.Image finalImg = circ;
      if (backgroundBytes != null) {
        final img.Image? bg = img.decodeImage(backgroundBytes);
        if (bg != null) {
          final img.Image bgRes = img.copyResize(bg, width: size, height: size);
          finalImg = _compositeForegroundOverBackground(circ, bgRes);
        }
      }

      final bytes = finalImg.hasAlpha
          ? Uint8List.fromList(img.encodePng(finalImg))
          : Uint8List.fromList(img.encodeJpg(finalImg, quality: 95));
      _pushHistory(bytes);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: bytes));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> textToEdit(String prompt) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final p = prompt.toLowerCase();
      if (p.contains('cinematic')) {
        await applyFilter('festival_pop');
        await lensVignette(0.25);
      } else if (p.contains('bright') || p.contains('expose')) {
        updateAdjustments(brightness: 0.08, contrast: 0.06, saturation: 0.06);
        await applyAdjustments();
      } else if (p.contains('portrait') || p.contains('skin')) {
        await autoEnhance(sharpenAmount: 0.3);
      } else if (p.contains('bokeh') || p.contains('blur')) {
        await tiltShift(center: 0.5, span: 0.3, horizontal: false);
      } else {
        await autoEnhance();
      }
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  Future<void> autoEnhance({double sharpenAmount = 0.6}) async {
    if (state.editedBytes == null) return;
    try {
      emit(state.copyWith(status: EditorStatus.loading));
      final img.Image? src = img.decodeImage(state.editedBytes!);
      if (src == null) throw Exception('Unable to decode image');

      double avg = 0;
      final int w = src.width, h = src.height, n = w * h;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final img.Pixel p = src.getPixel(x, y);
          avg += (0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
        }
      }
      avg /= n * 255.0;

      final double exposureDelta = (0.5 - avg) * 0.3;
      final double saturation = 0.12;
      final double contrast = 0.09;

      img.Image out = img.adjustColor(
        src,
        brightness: exposureDelta,
        saturation: saturation,
        contrast: contrast,
      );
      final img.Image blurred = img.gaussianBlur(out, radius: 2);
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final img.Pixel p0 = out.getPixel(x, y);
          final img.Pixel p1 = blurred.getPixel(x, y);
          int r = (p0.r + sharpenAmount * (p0.r - p1.r)).round().clamp(0, 255);
          int g = (p0.g + sharpenAmount * (p0.g - p1.g)).round().clamp(0, 255);
          int b = (p0.b + sharpenAmount * (p0.b - p1.b)).round().clamp(0, 255);
          out.setPixelRgba(x, y, r, g, b, p0.a);
        }
      }

      final result = Uint8List.fromList(img.encodeJpg(out, quality: 95));
      _pushHistory(result);
      emit(state.copyWith(status: EditorStatus.ready, editedBytes: result));
    } catch (e) {
      emit(state.copyWith(status: EditorStatus.error, message: e.toString()));
    }
  }

  // ----------------- Analysis Helpers (scene/emotion) ------------------------
  Future<String> detectScene() async {
    if (state.editedBytes == null) return 'unknown';
    final img.Image? src = img.decodeImage(state.editedBytes!);
    if (src == null) return 'unknown';
    int bright = 0, green = 0, blue = 0;
    for (int y = 0; y < src.height; y += src.height ~/ 10 + 1) {
      for (int x = 0; x < src.width; x += src.width ~/ 10 + 1) {
        final p = src.getPixel(x, y);
        bright += (p.r + p.g + p.b) ~/ 3;
        green += p.g;
        blue += p.b;
      }
    }
    if (green > blue && green > bright ~/ 2) return 'nature';
    if (blue > green && blue > bright ~/ 2) return 'water/sky';
    if (bright > 200 * 10) return 'bright/indoor';
    return 'general';
  }

  Future<String> detectDominantEmotion() async {
    return 'neutral';
  }

  // ----------------- Batch / Export ----------------------------------------
  Future<List<Uint8List>> applyBatch(
    List<Uint8List> inputs,
    Future<Uint8List> Function(Uint8List) op,
  ) async {
    final List<Uint8List> results = [];
    for (final b in inputs) {
      final Uint8List out = await op(b);
      results.add(out);
    }
    return results;
  }

  Future<Uint8List> exportImage(
    Uint8List bytes, {
    ExportFormat format = ExportFormat.jpeg,
    int quality = 90,
  }) async {
    final img.Image? src = img.decodeImage(bytes);
    if (src == null) throw Exception('Invalid image for export');
    switch (format) {
      case ExportFormat.png:
        return Uint8List.fromList(img.encodePng(src));
      case ExportFormat.webp:
        try {
          return Uint8List.fromList(img.encodePng(src));
        } catch (_) {
          return Uint8List.fromList(img.encodeJpg(src, quality: quality));
        }
      case ExportFormat.jpeg:
      default:
        return Uint8List.fromList(img.encodeJpg(src, quality: quality));
    }
  }

  // ----------------- Utility / Misc ---------------------------------------
  Future<List<String>> suggestEdits() async {
    final scene = await detectScene();
    if (scene == 'nature') return ['forest_green', 'vignette', 'autoEnhance'];
    if (scene == 'water/sky') return ['gedeo_warm', 'autoEnhance'];
    if (scene == 'bright/indoor') return ['bw_classic', 'autoEnhance'];
    return ['autoEnhance'];
  }
}
