import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _currentIndex = 0;

  static const List<_OnboardingItem> _items = [
    _OnboardingItem(
      title: 'Выбирайте любимые блюда',
      accentWord: 'любимые',
      subtitle: 'Удобный каталог, категории, поиск и быстрый заказ.',
      imagePath: 'assets/images/onboarding_1.jpg',
      fallbackIcon: Icons.ramen_dining_rounded,
    ),
    _OnboardingItem(
      title: 'Оформляйте доставку и самовывоз',
      accentWord: 'доставку',
      subtitle: 'Выберите удобное время получения заказа.',
      imagePath: 'assets/images/onboarding_2.jpg',
      fallbackIcon: Icons.delivery_dining_rounded,
    ),
    _OnboardingItem(
      title: 'Бронируйте столики',
      accentWord: 'столики',
      subtitle: 'Планируйте визит в ресторан прямо из приложения.',
      imagePath: 'assets/images/onboarding_3.jpg',
      fallbackIcon: Icons.table_restaurant_rounded,
    ),
  ];

  void _next() {
    if (_currentIndex == _items.length - 1) {
      context.go('/shell');
      return;
    }

    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  double _scrollPage() {
    if (!_controller.hasClients) return _currentIndex.toDouble();
    return _controller.page ?? _currentIndex.toDouble();
  }

  Widget _buildHeroImage(_OnboardingItem item, int index, double imageHeight) {
    return SizedBox(
      height: imageHeight,
      width: double.infinity,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final page = _scrollPage();
            final distance = (page - index).abs().clamp(0.0, 1.0);
            final opacity = lerpDouble(1.0, 0.5, distance)!;
            final scale = lerpDouble(1.0, 0.96, distance)!;
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topCenter,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      item.imagePath,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      width: double.infinity,
                      height: double.infinity,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) =>
                          _OnboardingImageFallback(icon: item.fallbackIcon),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.0),
                            AppColors.primary.withValues(alpha: 0.06),
                            AppColors.primary.withValues(alpha: 0.14),
                            AppColors.primaryDark.withValues(alpha: 0.55),
                            AppColors.primaryDark,
                          ],
                          stops: const [0.0, 0.28, 0.52, 0.82, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final imageHeight = mq.size.height * 0.48;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.textPrimary,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.backgroundTop,
                      AppColors.background,
                      AppColors.primaryDark.withValues(alpha: 0.92),
                      AppColors.primaryDark,
                    ],
                    stops: const [0.0, 0.12, 0.38, 1.0],
                  ),
                ),
              ),
            ),
            PageView.builder(
              controller: _controller,
              itemCount: _items.length,
              onPageChanged: (value) => setState(() => _currentIndex = value),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroImage(item, index, imageHeight),
                    Expanded(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primaryDark,
                              AppColors.textPrimary,
                            ],
                            stops: [0.0, 1.0],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 8),
                              _OnboardingTitle(
                                title: item.title,
                                accentWord: item.accentWord,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                              const Spacer(),
                              SizedBox(height: mq.padding.bottom + 132),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, right: 12),
                  child: Material(
                    elevation: 6,
                    shadowColor: Colors.black45,
                    borderRadius: BorderRadius.circular(22),
                    color: AppColors.primaryDark.withValues(alpha: 0.92),
                    child: InkWell(
                      onTap: () => context.go('/shell'),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.95),
                            width: 1.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        child: const Text(
                          'Пропустить',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 16 + mq.padding.bottom,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentIndex == index ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentIndex == index
                              ? AppColors.accent
                              : Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.textPrimary,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      child: Text(
                        _currentIndex == _items.length - 1 ? 'Начать' : 'Далее',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String accentWord;
  final String subtitle;
  final String imagePath;
  final IconData fallbackIcon;

  const _OnboardingItem({
    required this.title,
    required this.accentWord,
    required this.subtitle,
    required this.imagePath,
    required this.fallbackIcon,
  });
}

class _OnboardingTitle extends StatelessWidget {
  const _OnboardingTitle({
    required this.title,
    required this.accentWord,
  });

  final String title;
  final String accentWord;

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1.15,
      color: Colors.white,
    );
    const accentStyle = TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      height: 1.15,
      color: AppColors.accent,
    );

    final i = title.indexOf(accentWord);
    if (accentWord.isEmpty || i < 0) {
      return Text(
        title,
        textAlign: TextAlign.center,
        style: baseStyle,
      );
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: title.substring(0, i)),
          TextSpan(text: accentWord, style: accentStyle),
          TextSpan(text: title.substring(i + accentWord.length)),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _OnboardingImageFallback extends StatelessWidget {
  const _OnboardingImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.94 + 0.06 * value,
            child: child,
          ),
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: AppColors.primary.withValues(alpha: 0.2),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 88,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary.withValues(alpha: 0.0),
                  AppColors.primaryDark.withValues(alpha: 0.75),
                  AppColors.primaryDark,
                ],
                stops: const [0.35, 0.85, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
