import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/order_card.dart';
import '../../../data/models/order_model.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _error;

  bool _isCanceledOrder(OrderModel order) =>
      order.orderStatusId == 7 ||
      (order.orderStatusTitle ?? '').toLowerCase().contains('отмен');

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
      final orders = await AppDi.adminRepository.getAdminOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить заказы.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeStatus(OrderModel order) async {
    if (_isCanceledOrder(order)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя изменить статус отмененного заказа.')),
      );
      return;
    }

    int selectedStatus = order.orderStatusId;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text('Статус заказа №${order.id}'),
                  content: DropdownButtonFormField<int>(
                    value: selectedStatus,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Новый')),
                      DropdownMenuItem(value: 2, child: Text('Подтвержден')),
                      DropdownMenuItem(value: 3, child: Text('Готовится')),
                      DropdownMenuItem(value: 4, child: Text('Готов')),
                      DropdownMenuItem(value: 5, child: Text('Доставляется')),
                      DropdownMenuItem(value: 6, child: Text('Завершен')),
                      DropdownMenuItem(value: 7, child: Text('Отменен')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedStatus = value ?? 1;
                      });
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Сохранить'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      await AppDi.adminRepository.updateOrderStatus(
        orderId: order.id,
        orderStatusId: selectedStatus,
      );
      await _loadOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось обновить статус заказа.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Заказы')),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем заказы...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadOrders,
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final order = _orders[index];
                      final canChangeStatus = !_isCanceledOrder(order);
                      return OrderCard(
                        order: order,
                        onTap: () => context.push('/admin/orders/details', extra: order),
                        onRepeat: null,
                        onCancel: null,
                        onEdit: canChangeStatus ? () => _changeStatus(order) : null,
                      );
                    },
                  ),
                ),
    );
  }
}