import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/dish_thumbnail.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/price_row.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/quantity_selector.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../shared/enums/order_status.dart';
import '../../../shared/enums/user_role.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<CartItemModel> _items = [];
  bool _isLoading = true;
  String? _error;
  bool _actionLoading = false;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roleTitle = await AppDi.sessionService.getRole();
      final items = await AppDi.cartRepository.getCartItems();
      if (!mounted) return;

      setState(() {
        _isStaff = UserRole.fromTitle(roleTitle).isStaff;
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить корзину.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _increase(int index) async {
    if (_isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Для менеджера и администратора добавление блюд в корзину недоступно',
          ),
        ),
      );
      return;
    }
    final item = _items[index];

    try {
      setState(() => _actionLoading = true);

      await AppDi.cartRepository.updateCartItem(
        cartItemId: item.id,
        quantity: item.quantity + 1,
        comment: item.comment,
        selectedOptions: item.selectedOptions,
      );

      await _loadCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось изменить количество блюда.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _decrease(int index) async {
    final item = _items[index];

    if (item.quantity <= 1) {
      await _remove(index);
      return;
    }

    try {
      setState(() => _actionLoading = true);

      await AppDi.cartRepository.updateCartItem(
        cartItemId: item.id,
        quantity: item.quantity - 1,
        comment: item.comment,
        selectedOptions: item.selectedOptions,
      );

      await _loadCart();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось изменить количество блюда.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _remove(int index) async {
    final item = _items[index];

    try {
      setState(() => _actionLoading = true);

      await AppDi.cartRepository.removeCartItem(item.id);
      await _loadCart();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Блюдо удалено из корзины')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось удалить блюдо из корзины.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _clearCart() async {
    try {
      setState(() => _actionLoading = true);

      await AppDi.cartRepository.clearCart();
      await _loadCart();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Корзина очищена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось очистить корзину.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  double get _subtotal => _items.fold<double>(
        0,
        (sum, item) => sum + ((item.dish?.price ?? 0) * item.quantity),
      );

  Future<bool> _hasActiveOrder() async {
    final orders = await AppDi.orderRepository.getOrders();
    return orders.any(
      (order) => OrderStatus.fromTitle(order.orderStatusTitle).blocksNewOrder,
    );
  }

  Widget _buildDishImage(String? photoPath) {
    return DishThumbnail(
      photoPath: photoPath,
      size: 84,
      borderRadius: BorderRadius.circular(12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _subtotal;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Корзина'),
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _actionLoading ? null : _clearCart,
              child: const Text('Очистить'),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем корзину...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadCart,
                )
              : _items.isEmpty
                  ? const EmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Корзина пуста',
                      subtitle:
                          'Добавьте блюда из меню, чтобы оформить заказ.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCart,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        child: Column(
                          children: [
                            if (_isStaff)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Для ролей менеджер и администратор оформление заказа и добавление блюд в корзину недоступны.',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (_, index) {
                                  final item = _items[index];
                                  final dish = item.dish;

                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            child: _buildDishImage(
                                              dish?.photoPath,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  dish?.title ?? 'Блюдо',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 16,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '${(dish?.price ?? 0).toStringAsFixed(2)} ₽',
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                                if (item.selectedOptions !=
                                                        null &&
                                                    item.selectedOptions!
                                                        .trim()
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    item.selectedOptions!,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: AppColors.textHint,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 12),
                                                QuantitySelector(
                                                  value: item.quantity,
                                                  onDecrease: _actionLoading
                                                      ? () {}
                                                      : () => _decrease(index),
                                                  onIncrease: _actionLoading
                                                      ? () {}
                                                      : () => _increase(index),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _actionLoading
                                                ? null
                                                : () => _remove(index),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  children: [
                                    PriceRow(
                                      label: 'Товары',
                                      value: '${_subtotal.toStringAsFixed(2)} ₽',
                                    ),
                                    const Divider(height: 28),
                                    PriceRow(
                                      label: 'Итого',
                                      value: '${total.toStringAsFixed(2)} ₽',
                                      isTotal: true,
                                    ),
                                    const SizedBox(height: 18),
                                    PrimaryButton(
                                      text: 'Оформить заказ',
                                      onPressed: () async {
                                        if (_isStaff) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Для менеджера и администратора оформление заказа недоступно',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        final hasActiveOrder = await _hasActiveOrder();
                                        if (!mounted) return;
                                        if (hasActiveOrder) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'У вас уже есть активный заказ. Дождитесь завершения или отмените его перед новым заказом.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        context.push('/checkout');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }
}