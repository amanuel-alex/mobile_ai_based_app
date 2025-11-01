import 'package:flutter/material.dart';
import 'package:mobile_ai_photo_editor/shared/styles/app_colors.dart';

class AppButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool expanded;

  const AppButton({super.key, required this.onPressed, required this.label, this.icon, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.touch_app),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}
