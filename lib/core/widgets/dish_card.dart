import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/dish_model.dart';

class DishCard extends StatelessWidget {
  final DishModel dish;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const DishCard({
    super.key,
    required this.dish,
    this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: double.infinity,
      color: AppColors.inputFill,
      child: Icon(
        Icons.restaurant_menu_rounded,
        size: 44,
        color: AppColors.textHint.withValues(alpha: 0.6),
      ),
    );

    final image = (dish.photoPath != null && dish.photoPath!.isNotEmpty)
        ? CachedNetworkImage(
            imageUrl: dish.photoPath!,
            fit: BoxFit.cover,
            width: double.infinity,
            fadeInDuration: const Duration(milliseconds: 450),
            fadeOutDuration: const Duration(milliseconds: 220),
            placeholderFadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, __) => Container(
              color: AppColors.inputFill,
              alignment: Alignment.center,
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
            ),
            errorWidget: (_, __, ___) => placeholder,
          )
        : placeholder;

    return Material(
      color: AppColors.card,
      elevation: 2,
      shadowColor: AppColors.cardShadow,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 148,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.35),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                dish.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 17,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                dish.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${dish.price.toStringAsFixed(2)} ₽',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  FilledButton(
                    onPressed: dish.isAvailable ? onAddToCart : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      maximumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                      backgroundColor: dish.isAvailable ? AppColors.primary : AppColors.disabled,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, size: 22),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
