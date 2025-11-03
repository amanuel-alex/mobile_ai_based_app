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
          // Show different layouts based on state
          if (state.editedBytes == null) {
            // Full screen for image picker
            return _buildImagePicker(context);
          } else {
            // Editing layout with image and tools
            return Column(
              children: [
                // Image preview - takes most space
                Expanded(
                  flex: 3, // 75% of space for image
                  child: _isFullScreen
                      ? _buildFullScreenPreview(state)
                      : _buildPreview(context, state),
                ),

                // Only show tools when not in fullscreen
                if (!_isFullScreen) ...[
                  _buildToolbar(context),
                  // Panel with constrained height
                  Container(
                    height: MediaQuery.of(context).size.height * 0.3,
                    child: _buildPanel(context, state),
                  ),
                ],
              ],
            );
          }
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
                  onPressed: () => _saveImageWithConfirmation(context),
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
      return Container();
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  size: 80,
                  color: Colors.blue.withOpacity(0.3),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Professional AI Photo Editor',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Advanced image processing with AI-powered enhancements and professional tools',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    onPressed: () => _pickImageFromGallery(context),
                    label: 'Pick from Gallery',
                    icon: Icons.photo_library,
                    expanded: true,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    onPressed: () => _pickImageFromCamera(context),
                    label: 'Use Camera',
                    icon: Icons.photo_camera,
                    expanded: true,
                  ),
                ),
              ],
            ),
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
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 8,
            offset: Offset(0, -2),
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
      padding: const EdgeInsets.all(12),
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
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFeatureCard(
            context,
            'AI Auto Enhance',
            'Smart automatic enhancements',
            Icons.enhance_photo_translate,
            Colors.blue,
            state.editedBytes == null ? null : () => _applyAutoEnhance(context),
          ),
          const SizedBox(height: 8),
          _buildFeatureCard(
            context,
            'Magic Edit',
            'One-tap professional enhancement',
            Icons.auto_fix_high,
            Colors.purple,
            state.editedBytes == null ? null : () => _applyMagicEdit(context),
          ),
          const SizedBox(height: 8),
          _buildFeatureCard(
            context,
            'Portrait Enhancer',
            'Perfect for portraits and selfies',
            Icons.face,
            Colors.pink,
            state.editedBytes == null
                ? null
                : () => _applyPortraitEnhancer(context),
          ),
          const SizedBox(height: 8),
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
      {
        'id': 'vivid',
        'label': 'Vivid',
        'color': Colors.red,
        'icon': Icons.filter_vintage
      },
      {
        'id': 'dramatic',
        'label': 'Dramatic',
        'color': Colors.purple,
        'icon': Icons.filter_vintage
      },
      {
        'id': 'warm',
        'label': 'Warm',
        'color': Colors.orange,
        'icon': Icons.filter_vintage
      },
      {
        'id': 'cool',
        'label': 'Cool',
        'color': Colors.blue,
        'icon': Icons.filter_vintage
      },
      {
        'id': 'cinematic',
        'label': 'Cinematic',
        'color': Colors.indigo,
        'icon': Icons.filter_vintage
      },
      {
        'id': 'vintage',
        'label': 'Vintage',
        'color': Colors.brown,
        'icon': Icons.filter_vintage
      },
      {
        'id': 'bw_high_contrast',
        'label': 'B&W High Contrast',
        'color': Colors.grey,
        'icon': Icons.filter_b_and_w
      },
      {
        'id': 'bw_classic',
        'label': 'B&W Classic',
        'color': Colors.grey,
        'icon': Icons.filter_b_and_w
      },
      {
        'id': 'dramatic_bw',
        'label': 'Dramatic B&W',
        'color': Colors.black,
        'icon': Icons.filter_b_and_w
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            'AI Magic Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected = state.appliedFilterId == filter['id'];
              return Container(
                width: 80,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildHorizontalFilterItem(
                    filter, isSelected, state, context),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalFilterItem(Map<String, dynamic> filter,
      bool isSelected, EditorState state, BuildContext context) {
    return GestureDetector(
      onTap: state.editedBytes == null
          ? null
          : () {
              context.read<EditorCubit>().applyFilter(filter['id']!);
              _showFilterAppliedSnackbar(context, filter['label']!);
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
                filter['icon'] as IconData? ?? Icons.filter_vintage,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                filter['label']!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustPanel(BuildContext context, EditorState state) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed: state.editedBytes == null
                      ? null
                      : () {
                          context.read<EditorCubit>().applyAdjustments();
                          _showSuccessSnackbar(context, 'Adjustments applied!');
                        },
                  label: 'Apply All',
                  icon: Icons.check,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  onPressed: state.originalBytes == null
                      ? null
                      : () {
                          context.read<EditorCubit>().reset();
                          _showSuccessSnackbar(context, 'Reset to original!');
                        },
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
    final effects = [
      {
        'id': 'tilt_shift',
        'label': 'Tilt-Shift',
        'icon': Icons.blur_on,
        'color': Colors.purple,
      },
      {
        'id': 'gaussian',
        'label': 'Gaussian',
        'icon': Icons.blur_circular,
        'color': Colors.blue,
      },
      {
        'id': 'vignette',
        'label': 'Vignette',
        'icon': Icons.vignette,
        'color': Colors.brown,
      },
      {
        'id': 'grain',
        'label': 'Film Grain',
        'icon': Icons.grain,
        'color': Colors.orange,
      },
    ];

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Horizontal effects scroll
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  'Special Effects',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: effects.length,
                  itemBuilder: (context, index) {
                    final effect = effects[index];
                    return Container(
                      width: 70,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildHorizontalEffectItem(effect, state, context),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Blur controls
          _buildSlider(
            label: 'Blur Intensity',
            value: _blurIntensity,
            onChanged: (v) => setState(() => _blurIntensity = v),
          ),

          const SizedBox(height: 12),

          // Apply button
          AppButton(
            onPressed: state.editedBytes == null
                ? null
                : () {
                    context.read<EditorCubit>().applyBlurEffect(
                          intensity: _blurIntensity,
                          isTiltShift: _isTiltShift,
                        );
                    _showSuccessSnackbar(context, 'Blur effect applied!');
                  },
            label: 'Apply Blur Effect',
            icon: Icons.blur_on,
            expanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalEffectItem(
      Map<String, dynamic> effect, EditorState state, BuildContext context) {
    return GestureDetector(
      onTap: state.editedBytes == null
          ? null
          : () {
              _showEffectAppliedSnackbar(context, effect['label']!);
            },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: effect['color'] as Color? ?? Colors.grey,
                shape: BoxShape.circle,
              ),
              child: Icon(
                effect['icon'] as IconData? ?? Icons.blur_on,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                effect['label']!,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolsPanel(BuildContext context, EditorState state) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            onPressed: () => _pickImageFromGallery(context),
            label: 'Load New Image',
            icon: Icons.photo_library,
            expanded: true,
          ),
          const SizedBox(height: 8),
          AppButton(
            onPressed: state.editedBytes == null
                ? null
                : () => _saveImageWithConfirmation(context),
            label: 'Save to Gallery',
            icon: Icons.save,
            expanded: true,
          ),
          const SizedBox(height: 8),
          AppButton(
            onPressed: state.originalBytes == null
                ? null
                : () {
                    context.read<EditorCubit>().reset();
                    _showSuccessSnackbar(context, 'Reset to original!');
                  },
            label: 'Reset to Original',
            icon: Icons.restore,
            expanded: true,
          ),
          const SizedBox(height: 8),
          AppButton(
            onPressed: state.editedBytes == null
                ? null
                : () => setState(() => _isFullScreen = true),
            label: 'Fullscreen View',
            icon: Icons.fullscreen,
            expanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentSlider(String label, double value, IconData icon,
      ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
        ),
      ],
    );
  }

  // Action Methods
  Future<void> _pickImageFromGallery(BuildContext context) async {
    try {
      await context.read<EditorCubit>().pickImage();
    } catch (e) {
      _showErrorSnackbar(context, 'Failed to pick image: $e');
    }
  }

  Future<void> _pickImageFromCamera(BuildContext context) async {
    try {
      await context.read<EditorCubit>().pickImageFromCamera();
    } catch (e) {
      _showErrorSnackbar(context, 'Failed to capture image: $e');
    }
  }

  void _applyAutoEnhance(BuildContext context) {
    context.read<EditorCubit>().autoEnhance();
    _showSuccessSnackbar(context, 'AI Auto Enhance applied!');
  }

  void _applyMagicEdit(BuildContext context) {
    context.read<EditorCubit>().magicEdit();
    _showSuccessSnackbar(context, 'Magic Edit applied!');
  }

  void _applyPortraitEnhancer(BuildContext context) {
    context.read<EditorCubit>().applyFilter('portrait');
    _showSuccessSnackbar(context, 'Portrait enhancer applied!');
  }

  Future<void> _saveImageWithConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Image'),
        content: const Text('Do you want to save this image to your gallery?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<EditorCubit>().saveImage();
        _showSuccessSnackbar(context, 'Image saved successfully!');
      } catch (e) {
        _showErrorSnackbar(context, 'Failed to save image: $e');
      }
    }
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
                hintText: 'e.g. "make it look cinematic"',
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
                _showSuccessSnackbar(context, 'Processing your request...');
              }
            },
            child: const Text('Enhance'),
          ),
        ],
      ),
    );
  }

  void _showFilterAppliedSnackbar(BuildContext context, String filterName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$filterName filter applied'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showEffectAppliedSnackbar(BuildContext context, String effectName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$effectName effect applied'),
        duration: const Duration(seconds: 1),
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
        duration: const Duration(seconds: 2),
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
