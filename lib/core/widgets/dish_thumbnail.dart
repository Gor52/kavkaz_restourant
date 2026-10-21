import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/di.dart';
import '../../app/theme/app_colors.dart';

class DishThumbnail extends StatelessWidget {
  const DishThumbnail({
    super.key,
    required this.photoPath,
    this.size = 48,
    this.borderRadius,
  });

  final String? photoPath;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final child = _buildImage();
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      color: AppColors.inputFill,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_menu_rounded,
        size: size * 0.45,
        color: AppColors.textHint.withValues(alpha: 0.65),
      ),
    );
  }

  Widget _buildImage() {
    final raw = photoPath?.trim();
    if (raw == null || raw.isEmpty) {
      return _placeholder();
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: raw,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }

    if (raw.startsWith('/')) {
      final base = AppDi.apiService.dio.options.baseUrl;
      final resolved = Uri.parse(base).resolve(raw).toString();
      return CachedNetworkImage(
        imageUrl: resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }

    return Image.asset(
      raw,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }
}
