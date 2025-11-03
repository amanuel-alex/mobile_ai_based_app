import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_ai_photo_editor/features/presentation/bloc/editor_cubit.dart';
import 'package:mobile_ai_photo_editor/features/presentation/bloc/editor_state.dart';

class BackgroundPanel extends StatefulWidget {
  const BackgroundPanel({super.key});

  @override
  State<BackgroundPanel> createState() => _BackgroundPanelState();
}

class _BackgroundPanelState extends State<BackgroundPanel> {
  String _selectedBackgroundType = 'color';
  Color _selectedColor = Colors.white;
  double _blurIntensity = 0.0;

  final List<Color> _colorPresets = [
    Colors.white,
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.grey,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorCubit, EditorState>(
      builder: (context, state) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Background Type Selection
              _buildTypeSelector(),
              const SizedBox(height: 16),

              // Content based on selected type
              if (_selectedBackgroundType == 'color')
                ..._buildColorBackground(),
              if (_selectedBackgroundType == 'blur') ..._buildBlurBackground(),
              if (_selectedBackgroundType == 'transparent')
                ..._buildTransparentBackground(),

              const SizedBox(height: 16),

              // Action Buttons
              _buildActionButtons(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeSelector() {
    final List<Map<String, dynamic>> types = [
      {'id': 'color', 'icon': Icons.color_lens, 'label': 'Color'},
      {'id': 'blur', 'icon': Icons.blur_on, 'label': 'Blur'},
      {'id': 'transparent', 'icon': Icons.hd, 'label': 'Transparent'},
    ];

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: types.length,
        itemBuilder: (context, index) {
          final type = types[index];
          final isSelected = _selectedBackgroundType == type['id'];
          return Container(
            width: 70,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildTypeItem(type, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildTypeItem(Map<String, dynamic> type, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedBackgroundType = type['id']),
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
            Icon(
              type['icon'] as IconData,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              type['label']!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildColorBackground() {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Solid Colors',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Color Presets Grid
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _colorPresets.length,
        itemBuilder: (context, index) {
          final color = _colorPresets[index];
          final isSelected = _selectedColor == color;
          return GestureDetector(
            onTap: () => setState(() => _selectedColor = color),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey.shade400,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _buildBlurBackground() {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Blur Background',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildSlider(
        label: 'Blur Intensity',
        value: _blurIntensity,
        onChanged: (value) => setState(() => _blurIntensity = value),
      ),
    ];
  }

  List<Widget> _buildTransparentBackground() {
    return [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          'Transparent Background',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.hd,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            const Text(
              'Remove background and make it transparent',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
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
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, EditorState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _applyBackground(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check, size: 18),
                  SizedBox(width: 8),
                  Text('Apply Background'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _removeBackground(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Remove'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyBackground(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    switch (_selectedBackgroundType) {
      case 'color':
        cubit.changeBackgroundColor(_selectedColor);
        break;
      case 'blur':
        cubit.applyBackgroundBlur(_blurIntensity);
        break;
      case 'transparent':
        cubit.makeBackgroundTransparent();
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_getBackgroundTypeName()} background applied'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeBackground(BuildContext context) {
    context.read<EditorCubit>().removeBackground();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Background removed'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getBackgroundTypeName() {
    switch (_selectedBackgroundType) {
      case 'color':
        return 'Color';
      case 'blur':
        return 'Blur';
      case 'transparent':
        return 'Transparent';
      default:
        return 'Background';
    }
  }
}
