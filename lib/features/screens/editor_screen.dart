import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_ai_photo_editor/features/presentation/bloc/editor_cubit.dart';
import 'package:mobile_ai_photo_editor/features/presentation/bloc/editor_state.dart';
import '../../../shared/widgets/app_button.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  double _split = 0.5;
  String _activePanel = 'adjust';
  bool _isFullScreen = false;

  // Effect values
  double _blurIntensity = 0.5;
  bool _isTiltShift = false;

  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: _isFullScreen ? null : _buildAppBar(context),
      body: BlocConsumer<EditorCubit, EditorState>(
        listener: (context, state) {
          if (state.status == EditorStatus.error && state.message != null) {
            _showErrorSnackbar(context, state.message!);
          } else if (state.status == EditorStatus.success &&
              state.message != null) {
            _showSuccessSnackbar(context, state.message!);
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              if (!_isFullScreen)
                Expanded(child: _buildPreview(context, state)),
              if (_isFullScreen)
                Expanded(child: _buildFullScreenPreview(state)),
              if (!_isFullScreen) _buildToolbar(context),
              if (!_isFullScreen) _buildPanel(context, state),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'AI Photo Editor',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 2,
      shadowColor: Colors.black12,
      actions: [
        BlocBuilder<EditorCubit, EditorState>(
          builder: (context, state) {
            if (state.editedBytes == null) return const SizedBox();

            return Row(
              children: [
                IconButton(
                  onPressed:
                      state.canUndo ? context.read<EditorCubit>().undo : null,
                  icon: Icon(Icons.undo,
                      color: state.canUndo ? Colors.blue : Colors.grey),
                  tooltip: 'Undo',
                ),
                IconButton(
                  onPressed:
                      state.canRedo ? context.read<EditorCubit>().redo : null,
                  icon: Icon(Icons.redo,
                      color: state.canRedo ? Colors.blue : Colors.grey),
                  tooltip: 'Redo',
                ),
                IconButton(
                  onPressed: () =>
                      setState(() => _isFullScreen = !_isFullScreen),
                  icon: const Icon(Icons.fullscreen, color: Colors.blue),
                  tooltip: 'Fullscreen',
                ),
                IconButton(
                  onPressed: context.read<EditorCubit>().saveImage,
                  icon: const Icon(Icons.save, color: Colors.blue),
                  tooltip: 'Save',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, EditorState state) {
    if (state.status == EditorStatus.loading) {
      return _buildLoadingState(state);
    }

    if (state.editedBytes == null) {
      return _buildImagePicker(context);
    }

    return _buildImageComparison(state);
  }

  Widget _buildFullScreenPreview(EditorState state) {
    if (state.editedBytes == null) return Container();

    return Stack(
      children: [
        InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          child: Image.memory(state.editedBytes!, fit: BoxFit.contain),
        ),
        Positioned(
          top: 40,
          right: 20,
          child: IconButton(
            onPressed: () => setState(() => _isFullScreen = false),
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(EditorState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: state.isProcessing ? state.processingProgress : null,
                color: Colors.blue,
                strokeWidth: 4,
              ),
              if (state.isProcessing && state.processingProgress > 0)
                Text(
                  '${(state.processingProgress * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Processing...',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          if (state.isProcessing) const SizedBox(height: 8),
          if (state.isProcessing)
            const Text(
              'Applying AI enhancements',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 100,
                color: Colors.blue.withOpacity(0.3),
              ),
              const SizedBox(height: 32),
              const Text(
                'Professional AI Photo Editor',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Advanced image processing with AI-powered enhancements\nProfessional tools for perfect edits',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: context.read<EditorCubit>().pickImage,
                  label: 'Pick from Gallery',
                  icon: Icons.photo_library,
                  expanded: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  onPressed: context.read<EditorCubit>().pickImageFromCamera,
                  label: 'Use Camera',
                  icon: Icons.photo_camera,
                  expanded: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageComparison(EditorState state) {
    return Stack(
      children: [
        // After image (full)
        Positioned.fill(
          child: Image.memory(
            state.editedBytes!,
            fit: BoxFit.contain,
          ),
        ),

        // Before image (revealed by slider)
        if (state.originalBytes != null)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * _split,
                child: Image.memory(
                  state.originalBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

        // Slider overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Before',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'After',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _split,
                  onChanged: (value) => setState(() => _split = value),
                  activeColor: Colors.white,
                  inactiveColor: Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final List<Map<String, dynamic>> tools = [
      {'id': 'magic', 'icon': Icons.auto_fix_high, 'label': 'AI Magic'},
      {'id': 'filters', 'icon': Icons.filter_vintage, 'label': 'Filters'},
      {'id': 'adjust', 'icon': Icons.tune, 'label': 'Adjust'},
      {'id': 'effects', 'icon': Icons.blur_on, 'label': 'Effects'},
      {'id': 'tools', 'icon': Icons.build, 'label': 'Tools'},
    ];

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: tools.map((tool) {
          final isActive = _activePanel == tool['id'];
          return _ToolbarItem(
            icon: tool['icon'] as IconData,
            label: tool['label'] as String,
            isActive: isActive,
            onTap: () => setState(() => _activePanel = tool['id'] as String),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, EditorState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: _buildActivePanel(context, state),
    );
  }

  Widget _buildActivePanel(BuildContext context, EditorState state) {
    switch (_activePanel) {
      case 'magic':
        return _buildMagicPanel(context, state);
      case 'filters':
        return _buildFiltersPanel(context, state);
      case 'adjust':
        return _buildAdjustPanel(context, state);
      case 'effects':
        return _buildEffectsPanel(context, state);
      case 'tools':
        return _buildToolsPanel(context, state);
      default:
        return _buildAdjustPanel(context, state);
    }
  }

  Widget _buildMagicPanel(BuildContext context, EditorState state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildFeatureCard(
            context,
            'AI Auto Enhance',
            'Smart automatic enhancements',
            Icons.enhance_photo_translate,
            Colors.blue,
            state.editedBytes == null
                ? null
                : context.read<EditorCubit>().autoEnhance,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            'Magic Edit',
            'One-tap professional enhancement',
            Icons.auto_fix_high,
            Colors.purple,
            state.editedBytes == null
                ? null
                : context.read<EditorCubit>().magicEdit,
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            'Portrait Enhancer',
            'Perfect for portraits and selfies',
            Icons.face,
            Colors.pink,
            state.editedBytes == null
                ? null
                : () => context.read<EditorCubit>().applyFilter('portrait'),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            'Text to Edit',
            'Describe your desired look',
            Icons.text_fields,
            Colors.green,
            state.editedBytes == null
                ? null
                : () => _showTextEditDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String subtitle,
      IconData icon, Color color, VoidCallback? onTap) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFiltersPanel(BuildContext context, EditorState state) {
    final filters = [
      {'id': 'vivid', 'label': 'Vivid', 'color': Colors.red},
      {'id': 'dramatic', 'label': 'Dramatic', 'color': Colors.purple},
      {'id': 'warm', 'label': 'Warm', 'color': Colors.orange},
      {'id': 'cool', 'label': 'Cool', 'color': Colors.blue},
      {'id': 'cinematic', 'label': 'Cinematic', 'color': Colors.indigo},
      {'id': 'vintage', 'label': 'Vintage', 'color': Colors.brown},
      {
        'id': 'bw_high_contrast',
        'label': 'B&W High Contrast',
        'color': Colors.grey
      },
      {'id': 'bw_classic', 'label': 'B&W Classic', 'color': Colors.grey},
      {'id': 'dramatic_bw', 'label': 'Dramatic B&W', 'color': Colors.black},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: filters.length,
      itemBuilder: (context, index) {
        final filter = filters[index];
        final isSelected = state.appliedFilterId == filter['id'];
        return _buildFilterItem(filter, isSelected, state, context);
      },
    );
  }

  Widget _buildFilterItem(Map<String, dynamic> filter, bool isSelected,
      EditorState state, BuildContext context) {
    return GestureDetector(
      onTap: state.editedBytes == null
          ? null
          : () {
              context.read<EditorCubit>().applyFilter(filter['id']!);
            },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: filter['color'] as Color? ?? Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.filter_vintage,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filter['label']!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustPanel(BuildContext context, EditorState state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildAdjustmentSlider(
            'Brightness',
            state.brightness,
            Icons.brightness_6,
            (v) => context.read<EditorCubit>().updateAdjustments(brightness: v),
          ),
          _buildAdjustmentSlider(
            'Contrast',
            state.contrast,
            Icons.contrast,
            (v) => context.read<EditorCubit>().updateAdjustments(contrast: v),
          ),
          _buildAdjustmentSlider(
            'Saturation',
            state.saturation,
            Icons.color_lens,
            (v) => context.read<EditorCubit>().updateAdjustments(saturation: v),
          ),
          _buildAdjustmentSlider(
            'Exposure',
            state.exposure,
            Icons.exposure,
            (v) => context.read<EditorCubit>().updateAdjustments(exposure: v),
          ),
          _buildAdjustmentSlider(
            'Warmth',
            state.warmth,
            Icons.wb_sunny,
            (v) => context.read<EditorCubit>().updateAdjustments(warmth: v),
          ),
          _buildAdjustmentSlider(
            'Sharpness',
            state.sharpness,
            Icons.details,
            (v) => context.read<EditorCubit>().updateAdjustments(sharpness: v),
          ),
          _buildAdjustmentSlider(
            'Vignette',
            state.vignette,
            Icons.vignette,
            (v) => context.read<EditorCubit>().updateAdjustments(vignette: v),
          ),
          _buildAdjustmentSlider(
            'Blur',
            state.blur,
            Icons.blur_on,
            (v) => context.read<EditorCubit>().updateAdjustments(blur: v),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed: state.editedBytes == null
                      ? null
                      : context.read<EditorCubit>().applyAdjustments,
                  label: 'Apply All',
                  icon: Icons.check,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  onPressed: state.originalBytes == null
                      ? null
                      : context.read<EditorCubit>().reset,
                  label: 'Reset All',
                  icon: Icons.refresh,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEffectsPanel(BuildContext context, EditorState state) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildEffectCard(
            'Tilt-Shift Blur',
            'Selective focus effect',
            Icons.blur_on,
            Colors.purple,
            () => context
                .read<EditorCubit>()
                .applyBlurEffect(intensity: _blurIntensity, isTiltShift: true),
            state,
          ),
          const SizedBox(height: 12),
          _buildEffectCard(
            'Gaussian Blur',
            'Soft background blur',
            Icons.blur_circular,
            Colors.blue,
            () => context
                .read<EditorCubit>()
                .applyBlurEffect(intensity: _blurIntensity, isTiltShift: false),
            state,
          ),
          const SizedBox(height: 16),
          _buildSlider(
            label: 'Blur Intensity',
            value: _blurIntensity,
            onChanged: (v) => setState(() => _blurIntensity = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: const Text('Tilt-Shift'),
                  selected: _isTiltShift,
                  onSelected: (selected) =>
                      setState(() => _isTiltShift = selected),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: const Text('Gaussian'),
                  selected: !_isTiltShift,
                  onSelected: (selected) =>
                      setState(() => _isTiltShift = !selected),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolsPanel(BuildContext context, EditorState state) {
    return Column(
      children: [
        AppButton(
          onPressed: context.read<EditorCubit>().pickImage,
          label: 'Load New Image',
          icon: Icons.photo_library,
          expanded: true,
        ),
        const SizedBox(height: 12),
        AppButton(
          onPressed: state.editedBytes == null
              ? null
              : context.read<EditorCubit>().saveImage,
          label: 'Save to Gallery',
          icon: Icons.save,
          expanded: true,
        ),
        const SizedBox(height: 12),
        AppButton(
          onPressed: state.originalBytes == null
              ? null
              : context.read<EditorCubit>().reset,
          label: 'Reset to Original',
          icon: Icons.restore,
          expanded: true,
        ),
        const SizedBox(height: 12),
        AppButton(
          onPressed: state.editedBytes == null
              ? null
              : () => setState(() => _isFullScreen = true),
          label: 'Fullscreen View',
          icon: Icons.fullscreen,
          expanded: true,
        ),
        const SizedBox(height: 12),
        AppButton(
          onPressed: state.editedBytes == null
              ? null
              : () => _showTextEditDialog(context),
          label: 'Text to Edit',
          icon: Icons.text_fields,
          expanded: true,
        ),
      ],
    );
  }

  Widget _buildEffectCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback? onTap, EditorState state) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: state.editedBytes == null
            ? null
            : const Icon(Icons.play_arrow, color: Colors.purple),
        onTap: state.editedBytes == null ? null : onTap,
      ),
    );
  }

  Widget _buildAdjustmentSlider(String label, double value, IconData icon,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: TextStyle(
                        color: value.abs() > 0.1 ? Colors.blue : Colors.grey,
                        fontSize: 12,
                        fontWeight: value.abs() > 0.1
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Slider(
                  value: value,
                  min: -1.0,
                  max: 1.0,
                  onChanged: onChanged,
                  activeColor: Colors.blue,
                  inactiveColor: Colors.grey.shade300,
                  divisions: 20,
                  label: '${(value * 100).round()}%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          onChanged: onChanged,
          activeColor: Colors.blue,
          inactiveColor: Colors.grey.shade300,
          divisions: 10,
          label: '${(value * 100).round()}%',
        ),
      ],
    );
  }

  Future<void> _showTextEditDialog(BuildContext context) async {
    final textController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Text to Edit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Describe how you want to enhance your photo:'),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText:
                    'e.g. "make it look cinematic with dramatic lighting"',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final prompt = textController.text.trim();
              if (prompt.isNotEmpty) {
                Navigator.pop(context);
                context.read<EditorCubit>().textToEdit(prompt);
              }
            },
            child: const Text('Enhance'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _ToolbarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.blue : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive ? Colors.blue : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
