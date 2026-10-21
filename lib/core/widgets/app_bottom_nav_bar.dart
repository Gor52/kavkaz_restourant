import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class _NavItemSpec {
  const _NavItemSpec(this.outline, this.selected, this.label);

  final IconData outline;
  final IconData selected;
  final String label;
}

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showAdminTab;
  final bool showCartAndBooking;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showAdminTab = false,
    this.showCartAndBooking = true,
  });

  @override
  Widget build(BuildContext context) {
    final specs = <_NavItemSpec>[
      const _NavItemSpec(
        Icons.home_outlined,
        Icons.home_rounded,
        'Главная',
      ),
      const _NavItemSpec(
        Icons.restaurant_menu_outlined,
        Icons.restaurant_menu_rounded,
        'Меню',
      ),
      if (showCartAndBooking) ...[
        const _NavItemSpec(
          Icons.shopping_bag_outlined,
          Icons.shopping_bag_rounded,
          'Корзина',
        ),
        const _NavItemSpec(
          Icons.event_seat_outlined,
          Icons.event_seat_rounded,
          'Бронь',
        ),
      ],
      const _NavItemSpec(
        Icons.person_outline_rounded,
        Icons.person_rounded,
        'Профиль',
      ),
    ];
    if (showAdminTab) {
      specs.add(
        const _NavItemSpec(
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings_rounded,
          'Админ',
        ),
      );
    }

    final compact = specs.length >= 6;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundTop.withValues(alpha: 0.7),
            AppColors.background.withValues(alpha: 0.95),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 68,
            child: Row(
              children: List.generate(specs.length, (i) {
                final spec = specs[i];
                final selected = i == currentIndex;
                return Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(i),
                      splashColor: AppColors.primary.withValues(alpha: 0.12),
                      highlightColor: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 1,
                          vertical: 2,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 8 : 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary.withValues(alpha: 0.14)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                selected ? spec.selected : spec.outline,
                                size: 24,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textHint.withValues(alpha: 0.88),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              spec.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: compact ? 10.5 : 11.5,
                                fontWeight:
                                    selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textSecondary
                                        .withValues(alpha: 0.95),
                                height: 1.05,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
