import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../shared/enums/order_status.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/order_card.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../data/models/order_model.dart';

class OrdersHistoryPage extends StatefulWidget {
  const OrdersHistoryPage({super.key});

  @override
  State<OrdersHistoryPage> createState() => _OrdersHistoryPageState();
}

class _OrdersHistoryPageState extends State<OrdersHistoryPage> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _error;
  bool _actionLoading = false;

  bool _isEditable(OrderModel order) {
    return OrderStatus.fromTitle(order.orderStatusTitle) ==
        OrderStatus.newOrder;
  }

  bool _isCancelable(OrderModel order) {
    return OrderStatus.fromTitle(order.orderStatusTitle).canCustomerCancel;
  }

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orders = await AppDi.orderRepository.getOrders();

      if (!mounted) return;
      setState(() {
        _orders = orders;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(
          e,
          fallback: 'Не удалось загрузить историю заказов.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _repeatOrder(OrderModel order) async {
    try {
      setState(() => _actionLoading = true);

      await AppDi.orderRepository.repeatOrder(order.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заказ №${order.id} добавлен в корзину')),
      );
      context.push('/cart');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось повторить заказ.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    try {
      setState(() => _actionLoading = true);

      await AppDi.orderRepository.cancelOrder(order.id);
      await _loadOrders();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заказ №${order.id} отменен')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось отменить заказ.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/shell');
          },
        ),
        title: const Text('История заказов'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем заказы...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadOrders,
                )
              : _orders.isEmpty
                  ? const Center(
                      child: Text(
                        'У вас пока нет заказов',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadOrders,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(20),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (_, index) {
                          final order = _orders[index];

                          return OrderCard(
                            order: order,
                            onTap: () =>
                                context.push('/order-details', extra: order),
                            onEdit: _actionLoading || !_isEditable(order)
                                ? null
                                : () async {
                                    await context.push('/order-details', extra: order);
                                    if (mounted) {
                                      _loadOrders();
                                    }
                                  },
                            onRepeat: _actionLoading
                                ? null
                                : () => _repeatOrder(order),
                            onCancel: _actionLoading
                                ? null
                                : (_isCancelable(order) ? () => _cancelOrder(order) : null),
                          );
                        },
                      ),
                    ),
    );
  }
}