import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_ai_photo_editor/features/presentation/bloc/editor_cubit.dart';
import 'package:mobile_ai_photo_editor/features/presentation/bloc/editor_state.dart';
import 'package:mobile_ai_photo_editor/shared/widgets/app_button.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final CropController _cropController = CropController();
  bool _cropping = false;
  double _split = 0.5;
  String _activePanel = 'adjust'; // magic, filters, overlays, blur, splash, double, adjust
  // Blur (tilt-shift)
  double _tiltCenter = 0.5;
  double _tiltSpan = 0.3;
  bool _tiltHorizontal = true;
  // Color splash
  double _splashHue = 0.0; // 0..1
  double _splashTol = 0.08;
  // Double exposure
  double _doubleOpacity = 0.5;
  // Selective rect
  double _selCX = 0.5, _selCY = 0.5, _selW = 0.4, _selH = 0.4;
  double _selB = 0.0, _selC = 0.0, _selS = 0.0;
  // Lens
  double _vigStrength = 0.4;
  double _distAmount = 0.0; // -1..1
  double _chromaShift = 1.0;

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editor')),
      body: SafeArea(
        child: BlocConsumer<EditorCubit, EditorState>(
          listener: (context, state) {
            if (state.status == EditorStatus.error && state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!)));
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                Expanded(child: Padding(padding: const EdgeInsets.all(12.0), child: _buildPreview(state))),
                _buildToolbar(context, state),
                _buildPanel(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPreview(EditorState state) {
    if (state.status == EditorStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.editedBytes == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AppButton(
              onPressed: context.read<EditorCubit>().pickImage,
              label: 'Pick from Gallery',
              icon: Icons.photo_library,
              expanded: true,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: AppButton(
              onPressed: context.read<EditorCubit>().pickImageFromCamera,
              label: 'Use Camera',
              icon: Icons.photo_camera,
              expanded: true,
            ),
          ),
        ],
      );
    }

    if (_cropping) {
      return Crop(
        controller: _cropController,
        image: state.editedBytes!,
        onCropped: (bytes) {
          context.read<EditorCubit>().setEdited(bytes);
          setState(() => _cropping = false);
        },
        withCircleUi: false,
        initialSize: 0.8,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Stack(
          children: [
            Positioned.fill(child: _imageFromBytes(state.editedBytes!)),
            if (state.originalBytes != null)
              ClipRect(
                child: Align(alignment: Alignment.centerLeft, widthFactor: _split, child: _imageFromBytes(state.originalBytes!)),
              ),
            if (state.overlay != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: state.overlay == 'festival_frame' ? Colors.amber : Colors.greenAccent,
                        width: 8,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(bottom: 0, left: 0, right: 0, child: Slider(value: _split, onChanged: (v) => setState(() => _split = v))),
            // Undo / Redo quick buttons
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(onPressed: context.read<EditorCubit>().undo, icon: const Icon(Icons.undo)),
                  IconButton(onPressed: context.read<EditorCubit>().redo, icon: const Icon(Icons.redo)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _imageFromBytes(Uint8List bytes) => Image.memory(bytes, fit: BoxFit.contain);

  Widget _buildToolbar(BuildContext context, EditorState state) {
    Widget tab(String id, IconData icon, String label) {
      final active = _activePanel == id;
      return Expanded(
        child: TextButton.icon(
          onPressed: () => setState(() => _activePanel = id),
          icon: Icon(icon, color: active ? Theme.of(context).colorScheme.primary : Colors.black54),
          label: Text(label, style: TextStyle(color: active ? Theme.of(context).colorScheme.primary : Colors.black87)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Row(
        children: [
          tab('magic', Icons.auto_fix_high, 'Magic'),
          tab('filters', Icons.filter_vintage, 'Filters'),
          tab('overlays', Icons.crop_square, 'Overlays'),
          tab('blur', Icons.blur_on, 'Blur'),
          tab('splash', Icons.color_lens, 'Splash'),
          tab('double', Icons.layers, 'Double'),
          tab('selective', Icons.brush, 'Selective'),
          tab('lens', Icons.camera_outdoor, 'Lens'),
          tab('adjust', Icons.tune, 'Adjust'),
          tab('crop', Icons.crop, 'Crop'),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context, EditorState state) {
    switch (_activePanel) {
      case 'magic':
        return _panelWrap([
          AppButton(onPressed: state.editedBytes == null ? null : context.read<EditorCubit>().magicEdit, label: 'One-tap Magic', icon: Icons.auto_fix_high, expanded: true),
          const SizedBox(height: 8),
          AppButton(onPressed: state.editedBytes == null ? null : context.read<EditorCubit>().autoEnhance, label: 'Auto Enhance', icon: Icons.flash_on, expanded: true),
          const SizedBox(height: 8),
          AppButton(
            onPressed: state.editedBytes == null
                ? null
                : () async {
                    // pick mask image (painted mask) from gallery for local inpaint
                    final XFile? maskFile = await _picker.pickImage(source: ImageSource.gallery);
                    if (maskFile == null) return;
                    final maskBytes = await maskFile.readAsBytes();
                    if (!mounted) return;
                    await context.read<EditorCubit>().removeObjectLocal(maskBytes);
                  },
            label: 'Remove Object (mask)',
            icon: Icons.remove_circle,
            expanded: true,
          ),
          const SizedBox(height: 8),
          AppButton(
            onPressed: state.editedBytes == null
                ? null
                : () async {
                    // quick sketch
                    await context.read<EditorCubit>().photoToSketch(cartoon: false);
                  },
            label: 'Photo → Sketch',
            icon: Icons.brush,
            expanded: true,
          ),
          const SizedBox(height: 8),
          AppButton(
            onPressed: state.editedBytes == null
                ? null
                : () async {
                    await context.read<EditorCubit>().photoToSketch(cartoon: true);
                  },
            label: 'Photo → Cartoon',
            icon: Icons.emoji_emotions,
            expanded: true,
          ),
          const SizedBox(height: 8),
          AppButton(
            onPressed: state.editedBytes == null
                ? null
                : () async {
                    // text-to-edit prompt dialog
                    final prompt = await showDialog<String>(
                      context: context,
                      builder: (c) {
                        final tc = TextEditingController();
                        return AlertDialog(
                          title: const Text('Describe edit'),
                          content: TextField(controller: tc, decoration: const InputDecoration(hintText: 'e.g. make it cinematic')),
                          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, tc.text), child: const Text('Apply'))],
                        );
                      },
                    );
                    if (prompt != null && prompt.isNotEmpty) await context.read<EditorCubit>().textToEdit(prompt);
                  },
            label: 'Text → Edit',
            icon: Icons.text_fields,
            expanded: true,
          ),
        ]);
      case 'filters':
        return _panelWrap([_filterRow(context, state)]);
      case 'overlays':
        return _panelWrap([
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('None'), selected: state.overlay == null, onSelected: (_) => context.read<EditorCubit>().setOverlay(null)),
              ChoiceChip(label: const Text('Festival Frame'), selected: state.overlay == 'festival_frame', onSelected: (_) => context.read<EditorCubit>().setOverlay('festival_frame')),
              ChoiceChip(label: const Text('Green Border'), selected: state.overlay == 'green_border', onSelected: (_) => context.read<EditorCubit>().setOverlay('green_border')),
            ],
          ),
        ]);
      case 'blur':
        return _panelWrap([
          _slider(label: 'Center', value: _tiltCenter, onChanged: (v) => setState(() => _tiltCenter = v)),
          _slider(label: 'Span', value: _tiltSpan, onChanged: (v) => setState(() => _tiltSpan = v)),
          Row(children: [Expanded(child: AppButton(onPressed: () => setState(() => _tiltHorizontal = true), label: 'Horizontal', icon: Icons.swap_horiz)), const SizedBox(width: 8), Expanded(child: AppButton(onPressed: () => setState(() => _tiltHorizontal = false), label: 'Vertical', icon: Icons.swap_vert))]),
          AppButton(onPressed: state.editedBytes == null ? null : () => context.read<EditorCubit>().tiltShift(center: _tiltCenter, span: _tiltSpan, horizontal: _tiltHorizontal), label: 'Apply Tilt‑Shift', icon: Icons.blur_on, expanded: true),
        ]);
      case 'splash':
        return _panelWrap([
          _slider(label: 'Hue', value: _splashHue, onChanged: (v) => setState(() => _splashHue = v)),
          _slider(label: 'Tolerance', value: _splashTol, onChanged: (v) => setState(() => _splashTol = v)),
          AppButton(onPressed: state.editedBytes == null ? null : () => context.read<EditorCubit>().colorSplash(hue: _splashHue, tolerance: _splashTol), label: 'Apply Color Splash', icon: Icons.color_lens, expanded: true),
        ]);
      case 'double':
        return _panelWrap([
          _slider(label: 'Opacity', value: _doubleOpacity, onChanged: (v) => setState(() => _doubleOpacity = v)),
          AppButton(onPressed: state.editedBytes == null ? null : () async {
            final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
            if (file == null) return;
            final bytes = await file.readAsBytes();
            if (!mounted) return;
            await context.read<EditorCubit>().doubleExposure(bytes, opacity: _doubleOpacity);
          }, label: 'Blend with Image', icon: Icons.layers, expanded: true),
        ]);
      case 'selective':
        return _panelWrap([
          _slider(label: 'Center X', value: _selCX, onChanged: (v) => setState(() => _selCX = v)),
          _slider(label: 'Center Y', value: _selCY, onChanged: (v) => setState(() => _selCY = v)),
          _slider(label: 'Width', value: _selW, onChanged: (v) => setState(() => _selW = v)),
          _slider(label: 'Height', value: _selH, onChanged: (v) => setState(() => _selH = v)),
          const Divider(),
          _slider(label: 'Bright', value: _selB, onChanged: (v) => setState(() => _selB = v)),
          _slider(label: 'Contrast', value: _selC, onChanged: (v) => setState(() => _selC = v)),
          _slider(label: 'Saturation', value: _selS, onChanged: (v) => setState(() => _selS = v)),
          AppButton(onPressed: state.editedBytes == null ? null : () => context.read<EditorCubit>().selectiveAdjustRect(centerX: _selCX, centerY: _selCY, widthPct: _selW, heightPct: _selH, brightness: _selB, contrast: _selC, saturation: _selS), label: 'Apply Selective', icon: Icons.brush, expanded: true),
        ]);
      case 'lens':
        return _panelWrap([
          _slider(label: 'Vignette', value: _vigStrength, onChanged: (v) => setState(() => _vigStrength = v)),
          AppButton(onPressed: state.editedBytes == null ? null : () => context.read<EditorCubit>().lensVignette(_vigStrength), label: 'Apply Vignette', icon: Icons.blur_circular, expanded: true),
          const SizedBox(height: 8),
          _slider(label: 'Distortion', value: _distAmount, onChanged: (v) => setState(() => _distAmount = v)),
          AppButton(onPressed: state.editedBytes == null ? null : () => context.read<EditorCubit>().lensDistortion(_distAmount), label: 'Apply Distortion', icon: Icons.center_focus_weak, expanded: true),
          const SizedBox(height: 8),
          _slider(label: 'Chroma shift (px)', value: _chromaShift, onChanged: (v) => setState(() => _chromaShift = v)),
          AppButton(onPressed: state.editedBytes == null ? null : () => context.read<EditorCubit>().fixChromaticAberration(_chromaShift), label: 'Fix Chromatic Aberration', icon: Icons.merge_type, expanded: true),
        ]);
      case 'crop':
        return _panelWrap([
          AppButton(onPressed: context.read<EditorCubit>().pickImage, label: 'Pick', icon: Icons.photo_library, expanded: true),
          const SizedBox(height: 8),
          AppButton(onPressed: context.read<EditorCubit>().pickImageFromCamera, label: 'Camera', icon: Icons.photo_camera, expanded: true),
          const SizedBox(height: 8),
          AppButton(onPressed: state.editedBytes == null ? null : () => setState(() => _cropping = true), label: 'Start Crop', icon: Icons.crop, expanded: true),
        ]);
      case 'adjust':
      default:
        return _panelWrap([
          _slider(label: 'Brightness', value: state.brightness, onChanged: (v) => context.read<EditorCubit>().updateAdjustments(brightness: v)),
          _slider(label: 'Contrast', value: state.contrast, onChanged: (v) => context.read<EditorCubit>().updateAdjustments(contrast: v)),
          _slider(label: 'Saturation', value: state.saturation, onChanged: (v) => context.read<EditorCubit>().updateAdjustments(saturation: v)),
          Row(children: [
            Expanded(child: AppButton(onPressed: state.editedBytes == null ? null : context.read<EditorCubit>().applyAdjustments, label: 'Apply', icon: Icons.tune)),
            const SizedBox(width: 8),
            Expanded(child: AppButton(onPressed: state.originalBytes == null ? null : context.read<EditorCubit>().reset, label: 'Reset', icon: Icons.refresh)),
          ]),
        ]);
    }
  }

  Widget _panelWrap(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _filterRow(BuildContext context, EditorState state) {
    Widget chip(String id, String label) {
      final selected = state.appliedFilterId == id;
      return ChoiceChip(label: Text(label), selected: selected, onSelected: state.editedBytes == null ? null : (_) => context.read<EditorCubit>().applyFilter(id));
    }

    return Wrap(spacing: 8, children: [chip('gedeo_warm', 'Gedeo Warm'), chip('festival_pop', 'Festival Pop'), chip('forest_green', 'Forest Green'), chip('bw_classic', 'B/W Classic')]);
  }

  Widget _slider({required String label, required double value, required ValueChanged<double> onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), Slider(value: value, min: -1.0, max: 1.0, onChanged: onChanged)]);
  }
}
