import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/auth_required_navigation.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/quantity_selector.dart';
import '../../../data/models/dish_model.dart';
import '../../../shared/enums/user_role.dart';
import 'reviews_page.dart';

class DishDetailsPage extends StatefulWidget {
  final DishModel dish;

  const DishDetailsPage({
    super.key,
    required this.dish,
  });

  @override
  State<DishDetailsPage> createState() => _DishDetailsPageState();
}

class _DishDetailsPageState extends State<DishDetailsPage> {
  DishModel? _dish;
  bool _isLoading = true;
  bool _adding = false;
  String? _error;

  int _quantity = 1;
  final TextEditingController _optionsController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDish();
  }

  @override
  void dispose() {
    _optionsController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadDish() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dish = await AppDi.menuRepository.getDishById(widget.dish.id);

      if (!mounted) return;
      setState(() {
        _dish = dish;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить блюдо.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double get _total => (_dish?.price ?? 0) * _quantity;

  Widget _buildDishImage() {
    final url = _dish?.photoPath?.trim();
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => _buildImagePlaceholder(),
      );
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFF1ECE7),
      child: const Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: 56,
          color: AppColors.textHint,
        ),
      ),
    );
  }

  Future<void> _addToCart() async {
    final dish = _dish;
    if (dish == null) return;
    final optionsValidation = Validators.validateOptionalText(
      _optionsController.text,
      fieldName: 'Опции блюда',
      maxLength: 300,
    );
    if (optionsValidation != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(optionsValidation)),
      );
      return;
    }
    final commentValidation = Validators.validateComment(_commentController.text);
    if (commentValidation != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(commentValidation)),
      );
      return;
    }
    final isAuthorized = await AppDi.sessionService.isAuthorized();
    if (!isAuthorized) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для добавления в корзину войдите в аккаунт')),
      );
      context.push(buildAuthRequiredLocation(from: '/menu'));
      return;
    }
    final role = UserRole.fromTitle(await AppDi.sessionService.getRole());
    if (role.isStaff) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Менеджер и администратор не могут добавлять блюда в корзину',
          ),
        ),
      );
      return;
    }

    try {
      setState(() => _adding = true);

      await AppDi.cartRepository.addToCart(
        dishId: dish.id,
        quantity: _quantity,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        selectedOptions: _optionsController.text.trim().isEmpty
            ? null
            : _optionsController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Блюдо добавлено в корзину')),
      );
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('Требуется авторизация')) {
        context.go(buildAuthRequiredLocation(from: '/menu'));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось добавить блюдо в корзину.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _adding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: _isLoading
          ? const LoadingView(message: 'Загружаем блюдо...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadDish,
                )
              : _dish == null
                  ? const Center(child: Text('Блюдо не найдено'))
                  : CustomScrollView(
                      slivers: [
                        SliverAppBar(
                          expandedHeight: 280,
                          pinned: true,
                          flexibleSpace: FlexibleSpaceBar(
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildDishImage(),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.35),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dish!.title,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _dish!.description,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _InfoChip(
                                      icon: Icons.scale_rounded,
                                      label: '${_dish!.weight} г',
                                    ),
                                    if (_dish!.calories != null)
                                      _InfoChip(
                                        icon: Icons.local_fire_department_rounded,
                                        label: '${_dish!.calories} ккал',
                                      ),
                                    if (_dish!.allergens != null &&
                                        _dish!.allergens!.isNotEmpty)
                                      _InfoChip(
                                        icon: Icons.warning_amber_rounded,
                                        label: _dish!.allergens!,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  'Состав',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _dish!.ingredients,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  'Опции блюда',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _optionsController,
                                  maxLength: 300,
                                  decoration: const InputDecoration(
                                    hintText: 'Например: без лука, острый соус',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _commentController,
                                  maxLength: 300,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'Комментарий к блюду',
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_dish!.price.toStringAsFixed(2)} ₽',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    QuantitySelector(
                                      value: _quantity,
                                      onDecrease: () {
                                        if (_quantity > 1) {
                                          setState(() => _quantity--);
                                        }
                                      },
                                      onIncrease: () {
                                        setState(() => _quantity++);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ReviewsPage(dishId: _dish!.id),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.rate_review_rounded),
                                  label: const Text('Смотреть отзывы'),
                                ),
                                const SizedBox(height: 14),
                                PrimaryButton(
                                  text:
                                      'Добавить в корзину • ${_total.toStringAsFixed(2)} ₽',
                                  isLoading: _adding,
                                  onPressed: _addToCart,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}