import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const PriceRow({
    super.key,
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: isTotal ? 18 : 15,
      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
      color: AppColors.textPrimary,
    );

    return Row(
      children: [
        Expanded(
          child: Text(label, style: style),
        ),
        Text(value, style: style),
      ],
    );
  }
}