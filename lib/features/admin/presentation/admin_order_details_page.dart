import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/order_model.dart';

class AdminOrderDetailsPage extends StatefulWidget {
  final int orderId;
  final OrderModel? initialOrder;

  const AdminOrderDetailsPage({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  State<AdminOrderDetailsPage> createState() => _AdminOrderDetailsPageState();
}

class _AdminOrderDetailsPageState extends State<AdminOrderDetailsPage> {
  static const List<DropdownMenuItem<int>> _statusItems = [
    DropdownMenuItem(value: 1, child: Text('Новый')),
    DropdownMenuItem(value: 2, child: Text('Подтвержден')),
    DropdownMenuItem(value: 3, child: Text('Готовится')),
    DropdownMenuItem(value: 4, child: Text('Готов')),
    DropdownMenuItem(value: 5, child: Text('Доставляется')),
    DropdownMenuItem(value: 6, child: Text('Завершен')),
    DropdownMenuItem(value: 7, child: Text('Отменен')),
  ];

  OrderModel? _order;
  int _selectedStatusId = 1;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  bool get _isCanceledOrder =>
      (_order?.orderStatusId == 7) ||
      ((_order?.orderStatusTitle ?? '').toLowerCase().contains('отмен'));

  @override
  void initState() {
    super.initState();
    _order = widget.initialOrder;
    _selectedStatusId = widget.initialOrder?.orderStatusId ?? 1;
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order = await AppDi.adminRepository.getAdminOrderById(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _selectedStatusId = order.orderStatusId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить детали заказа.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveStatus() async {
    final order = _order;
    if (order == null || _isCanceledOrder) return;
    if (_selectedStatusId == order.orderStatusId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Статус не изменился.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await AppDi.adminRepository.updateOrderStatus(
        orderId: order.id,
        orderStatusId: _selectedStatusId,
      );
      await _loadOrder();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Статус заказа обновлен.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось обновить статус заказа.'))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return AppScaffold(
      appBar: AppBar(
        title: Text(order == null ? 'Детали заказа' : 'Заказ №${order.id}'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем детали заказа...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadOrder,
                )
              : order == null
                  ? ErrorState(
                      title: 'Заказ не найден',
                      subtitle: 'Не удалось получить данные заказа.',
                      onRetry: _loadOrder,
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: ListView(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Клиент: ${order.userFullName ?? 'Пользователь #${order.userId}'}'),
                                  const SizedBox(height: 8),
                                  Text('Телефон: ${(order.userPhone ?? '').trim().isEmpty ? 'не указан' : order.userPhone}'),
                                  const SizedBox(height: 8),
                                  Text('Email: ${(order.userEmail ?? '').trim().isEmpty ? 'не указан' : order.userEmail}'),
                                  const SizedBox(height: 8),
                                  Text('Тип получения: ${order.pickupTypeTitle ?? '-'}'),
                                  if ((order.deliveryAddressText ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('Адрес доставки: ${order.deliveryAddressText!.trim()}'),
                                  ],
                                  if ((order.deliveryAddressComment ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('Комментарий к адресу: ${order.deliveryAddressComment!.trim()}'),
                                  ],
                                  const SizedBox(height: 8),
                                  Text('Оплата: ${order.paymentMethodTitle ?? '-'}'),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Сумма: ${order.totalAmount.toStringAsFixed(2)} ₽',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Использовано бонусов: ${order.spentBonus}'),
                                  if ((order.comment ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text('Комментарий: ${order.comment!.trim()}'),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Позиции заказа',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 10),
                                  if (order.items.isEmpty)
                                    const Text('Состав заказа отсутствует')
                                  else
                                    ...order.items.map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Builder(
                                          builder: (_) {
                                            final title = (item.dishTitle ?? '').trim();
                                            final safeTitle = title.isNotEmpty ? title : 'Удаленное блюдо';
                                            return Text(
                                              '$safeTitle x${item.quantity} — ${item.itemTotal.toStringAsFixed(2)} ₽',
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            value: _selectedStatusId,
                            decoration: const InputDecoration(
                              labelText: 'Статус заказа',
                            ),
                            items: _statusItems,
                            onChanged: _isCanceledOrder
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedStatusId = value ?? order.orderStatusId;
                                    });
                                  },
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(
                            text: _isCanceledOrder ? 'Заказ отменен (изменение недоступно)' : 'Сохранить статус',
                            onPressed: _isCanceledOrder ? null : _saveStatus,
                            isLoading: _isSaving,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('Назад к списку заказов'),
                          ),
                        ],
                      ),
                    ),
    );
  }
}