import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/enums/order_status.dart';
import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/dish_thumbnail.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/price_row.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/order_item_model.dart';
import '../../../data/models/order_model.dart';

class OrderDetailsPage extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsPage({
    super.key,
    required this.order,
  });

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  OrderModel? _order;
  bool _isLoading = true;
  bool _actionLoading = false;
  String? _error;
  List<AddressModel> _addresses = [];
  int _availableBonus = 0;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final order = await AppDi.orderRepository.getOrderById(widget.order.id);
      final addresses = await AppDi.profileRepository.getAddresses();
      final bonusBalance = await AppDi.profileRepository.getBonusBalance();

      if (!mounted) return;
      setState(() {
        _order = order;
        _addresses = addresses;
        _availableBonus = bonusBalance;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить заказ.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String _orderItemTitle(OrderItemModel item) {
    final t = item.dishTitle?.trim();
    if (t != null && t.isNotEmpty) return t;
    return 'Удаленное блюдо';
  }

  Future<void> _repeatOrder() async {
    final order = _order;
    if (order == null) return;

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

  Future<void> _cancelOrder() async {
    final order = _order;
    if (order == null) return;

    try {
      setState(() => _actionLoading = true);
      await AppDi.orderRepository.cancelOrder(order.id);
      await _loadOrder();

      if (!mounted) return;
      await LocalNotificationService.instance.showNow(
        id: order.id,
        title: 'Заказ отменен',
        body: 'Заказ №${order.id} был отменен',
      );
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

  bool get _canEditOrder =>
      _order != null &&
      OrderStatus.fromTitle(_order!.orderStatusTitle) ==
          OrderStatus.newOrder;

  bool get _canCancelOrder =>
      _order != null &&
      OrderStatus.fromTitle(_order!.orderStatusTitle).canCustomerCancel;

  DateTime _mergeDateAndTime(DateTime base, TimeOfDay time) {
    return DateTime(base.year, base.month, base.day, time.hour, time.minute);
  }

  Future<void> _editOrder() async {
    final order = _order;
    if (order == null || !_canEditOrder) return;

    int pickupTypeId = order.pickupTypeId;
    int paymentMethodId = order.paymentMethodId;
    int? addressId = order.addressId;
    int spentBonus = order.spentBonus;
    TimeOfDay receiveTime = TimeOfDay.fromDateTime(order.receiveTime);
    final commentController = TextEditingController(text: order.comment ?? '');
    final bonusController = TextEditingController(text: order.spentBonus.toString());

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Изменить заказ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: pickupTypeId,
                      decoration: const InputDecoration(labelText: 'Способ получения'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Доставка')),
                        DropdownMenuItem(value: 2, child: Text('Самовывоз')),
                      ],
                      onChanged: (v) => setSheetState(() => pickupTypeId = v ?? 1),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      value: paymentMethodId,
                      decoration: const InputDecoration(labelText: 'Способ оплаты'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Наличными')),
                        DropdownMenuItem(value: 2, child: Text('Банковской картой')),
                        DropdownMenuItem(value: 3, child: Text('Онлайн-оплата')),
                      ],
                      onChanged: (v) => setSheetState(() => paymentMethodId = v ?? 1),
                    ),
                    if (pickupTypeId == 1) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int>(
                        value: addressId,
                        decoration: const InputDecoration(labelText: 'Адрес доставки'),
                        items: _addresses
                            .map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.addressText, maxLines: 1, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setSheetState(() => addressId = v),
                      ),
                    ],
                    const SizedBox(height: 10),
                    TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Время получения',
                        hintText: '${receiveTime.hour.toString().padLeft(2, '0')}:${receiveTime.minute.toString().padLeft(2, '0')}',
                        suffixIcon: const Icon(Icons.access_time_rounded),
                      ),
                      onTap: () async {
                        final selected = await showTimePicker(context: context, initialTime: receiveTime);
                        if (selected != null) {
                          setSheetState(() => receiveTime = selected);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: commentController,
                      maxLength: 300,
                      validator: Validators.validateComment,
                      decoration: const InputDecoration(labelText: 'Комментарий'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: bonusController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(labelText: 'Списать бонусов (доступно: $_availableBonus)'),
                      onChanged: (v) {
                        final parsed = int.tryParse(v.trim()) ?? 0;
                        setSheetState(() => spentBonus = parsed.clamp(0, _availableBonus));
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Отмена'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (pickupTypeId == 1 && addressId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Выберите адрес доставки')),
                                );
                                return;
                              }
                              final commentValidation = Validators.validateComment(
                                commentController.text,
                              );
                              if (commentValidation != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(commentValidation)),
                                );
                                return;
                              }
                              final bonusValidation = Validators.validateOptionalPositiveInt(
                                bonusController.text,
                                fieldName: 'бонусы',
                                min: 0,
                                max: 1000000,
                              );
                              if (bonusValidation != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(bonusValidation)),
                                );
                                return;
                              }
                              final parsedBonus = int.tryParse(bonusController.text.trim()) ?? 0;
                              if (parsedBonus > _availableBonus) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Недостаточно бонусов')),
                                );
                                return;
                              }
                              spentBonus = parsedBonus;
                              Navigator.pop(context, true);
                            },
                            child: const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) {
      commentController.dispose();
      bonusController.dispose();
      return;
    }

    try {
      setState(() => _actionLoading = true);
      final updated = await AppDi.orderRepository.updateOrderBeforeConfirmation(
        orderId: order.id,
        pickupTypeId: pickupTypeId,
        paymentMethodId: paymentMethodId,
        addressId: pickupTypeId == 1 ? addressId : null,
        receiveTimeIso: _mergeDateAndTime(order.receiveTime, receiveTime).toIso8601String(),
        comment: commentController.text.trim().isEmpty ? null : commentController.text.trim(),
        spentBonus: spentBonus,
      );
      if (!mounted) return;
      setState(() => _order = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ обновлен')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось изменить заказ.'))),
      );
    } finally {
      commentController.dispose();
      bonusController.dispose();
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text('Заказ №${widget.order.id}'),
        actions: [
          if (_canEditOrder)
            IconButton(
              onPressed: _actionLoading ? null : _editOrder,
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Изменить заказ',
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем заказ...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadOrder,
                )
              : _order == null
                  ? const Center(child: Text('Заказ не найден'))
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Статус: ${_order!.orderStatusTitle ?? '-'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (_canEditOrder) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Заказ можно изменить до подтверждения',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'Получение: ${_order!.pickupTypeTitle ?? '-'}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Оплата: ${_order!.paymentMethodTitle ?? '-'}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Время: ${_formatDateTime(_order!.receiveTime)}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (_order!.comment != null &&
                                    _order!.comment!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Комментарий: ${_order!.comment}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Состав заказа',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_order!.items.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Позиции заказа отсутствуют',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          ..._order!.items.map(
                            (item) => Card(
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: DishThumbnail(
                                    photoPath: item.dishPhoto,
                                    size: 48,
                                  ),
                                ),
                                title: Text(_orderItemTitle(item)),
                                subtitle: Text(
                                  '${item.quantity} × ${item.priceAtOrderTime.toStringAsFixed(2)} ₽',
                                ),
                                trailing: Text(
                                  '${item.itemTotal.toStringAsFixed(2)} ₽',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              children: [
                                PriceRow(
                                  label: 'Сумма заказа',
                                  value:
                                      '${_order!.totalAmount.toStringAsFixed(2)} ₽',
                                ),
                                const SizedBox(height: 10),
                                PriceRow(
                                  label: 'Списано бонусов',
                                  value: '${_order!.spentBonus} ₽',
                                ),
                                const Divider(height: 28),
                                PriceRow(
                                  label: 'Итого',
                                  value:
                                      '${_order!.totalAmount.toStringAsFixed(2)} ₽',
                                  isTotal: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_canCancelOrder)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      _actionLoading ? null : _cancelOrder,
                                  child: const Text('Отменить'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: PrimaryButton(
                                  text: 'Повторить',
                                  isLoading: _actionLoading,
                                  onPressed: _repeatOrder,
                                ),
                              ),
                            ],
                          )
                        else
                          PrimaryButton(
                            text: 'Повторить',
                            isLoading: _actionLoading,
                            onPressed: _repeatOrder,
                          ),
                      ],
                    ),
    );
  }
}