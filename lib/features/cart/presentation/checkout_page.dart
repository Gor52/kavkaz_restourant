import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/address_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/dish_thumbnail.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/price_row.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../data/models/order_model.dart';
import '../../profile/presentation/address_form_sheet.dart';
import '../../../shared/enums/order_status.dart';
import '../../../shared/enums/user_role.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _receiveTimeController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _bonusController = TextEditingController();

  List<AddressModel> _addresses = [];
  List<CartItemModel> _cartItems = [];

  bool _isLoading = true;
  bool _submitting = false;
  String? _error;
  bool _isStaff = false;

  int _selectedPickupTypeId = 1;
  int _selectedPaymentMethodId = 1;
  int? _selectedAddressId;

  int _availableBonus = 0;
  DateTime? _selectedReceiveDateTime;

  static const double _deliveryFeeRub = 199;

  static const List<_PickupTypeItem> _pickupTypes = [
    _PickupTypeItem(id: 1, title: 'Доставка'),
    _PickupTypeItem(id: 2, title: 'Самовывоз'),
  ];

  static const List<_PaymentMethodItem> _paymentMethods = [
    _PaymentMethodItem(id: 1, title: 'Наличными'),
    _PaymentMethodItem(id: 2, title: 'Банковской картой'),
    _PaymentMethodItem(id: 3, title: 'Онлайн-оплата'),
  ];

  @override
  void initState() {
    super.initState();
    _loadCheckoutData();
  }

  Future<void> _loadCheckoutData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final role = UserRole.fromTitle(await AppDi.sessionService.getRole());
      if (role.isStaff) {
        if (!mounted) return;
        setState(() {
          _isStaff = true;
          _addresses = [];
          _cartItems = [];
        });
        return;
      }
      final addresses = await AppDi.profileRepository.getAddresses();
      final cartItems = await AppDi.cartRepository.getCartItems();
      final bonusBalance = await AppDi.profileRepository.getBonusBalance();

      if (!mounted) return;

      setState(() {
        _addresses = addresses;
        _cartItems = cartItems;
        _availableBonus = bonusBalance;

        final defaultAddress = addresses.cast<AddressModel?>().firstWhere(
              (item) => item?.isDefault == true,
              orElse: () => addresses.isNotEmpty ? addresses.first : null,
            );

        _selectedAddressId = defaultAddress?.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(
          e,
          fallback: 'Не удалось загрузить данные для оформления.',
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

  double get _itemsSubtotal => _cartItems.fold<double>(
        0,
        (sum, item) => sum + ((item.dish?.price ?? 0) * item.quantity),
      );

  double get _deliveryCost =>
      _selectedPickupTypeId == 1 ? _deliveryFeeRub : 0;

  int get _spentBonus {
    final value = int.tryParse(_bonusController.text.trim()) ?? 0;
    if (value < 0) return 0;
    if (value > _availableBonus) return _availableBonus;
    return value;
  }

  double get _totalAmount {
    final total = _itemsSubtotal + _deliveryCost - _spentBonus;
    return total < 0 ? 0 : total;
  }

  Future<bool> _hasActiveOrder() async {
    final orders = await AppDi.orderRepository.getOrders();
    return orders.any(
      (order) => OrderStatus.fromTitle(order.orderStatusTitle).blocksNewOrder,
    );
  }

  Future<void> _openAddAddressSheet() async {
    if (_isStaff) return;
    final saved = await showAddressFormSheet(context);
    if (!mounted || saved == null) return;
    await _loadCheckoutData();
    if (!mounted) return;
    setState(() {
      _selectedAddressId = saved.id;
    });
  }

  List<DateTime> _buildReceiveSlotDateTimes() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final slots = <DateTime>[];
    for (var dayOffset = 0; dayOffset <= 1; dayOffset++) {
      final day = todayStart.add(Duration(days: dayOffset));
      for (var totalMin = 11 * 60; totalMin <= 22 * 60; totalMin += 30) {
        final h = totalMin ~/ 60;
        final m = totalMin % 60;
        final dt = DateTime(day.year, day.month, day.day, h, m);
        if (dt.isBefore(now.add(const Duration(minutes: 30)))) continue;
        slots.add(dt);
      }
    }
    return slots;
  }

  String _receiveSlotLabel(DateTime dt, DateTime now) {
    final d0 = DateTime(now.year, now.month, now.day);
    final dt0 = DateTime(dt.year, dt.month, dt.day);
    final dayAfter = d0.add(const Duration(days: 1));
    String prefix;
    if (dt0 == d0) {
      prefix = 'Сегодня';
    } else if (dt0 == dayAfter) {
      prefix = 'Завтра';
    } else {
      prefix = DateFormat('dd.MM').format(dt);
    }
    final t = DateFormat.Hm().format(dt);
    return '$prefix, $t';
  }

  Future<void> _pickReceiveTime() async {
    final now = DateTime.now();
    final slots = _buildReceiveSlotDateTimes();
    if (slots.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных интервалов. Попробуйте позже.'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Время доставки / самовывоза',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: slots.length,
                    itemBuilder: (_, i) {
                      final dt = slots[i];
                      final label = _receiveSlotLabel(dt, now);
                      return ListTile(
                        title: Text(label),
                        onTap: () {
                          setState(() {
                            _selectedReceiveDateTime = dt;
                            _receiveTimeController.text = label;
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitOrder() async {
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
    if (!_formKey.currentState!.validate()) return;

    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Корзина пуста')),
      );
      return;
    }

    if (_selectedPickupTypeId == 1 && _selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите адрес доставки')),
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

    final receiveDateTime = _selectedReceiveDateTime;
    if (receiveDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите время из списка доступных интервалов'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final order = await AppDi.orderRepository.createOrder(
        pickupTypeId: _selectedPickupTypeId,
        paymentMethodId: _selectedPaymentMethodId,
        addressId: _selectedPickupTypeId == 1 ? _selectedAddressId : null,
        receiveTimeIso: receiveDateTime.toIso8601String(),
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
        spentBonus: _spentBonus,
      );

      if (!mounted) return;

      try {
        await LocalNotificationService.instance.showNow(
          id: order.id,
          title: 'Заказ оформлен',
          body: 'Ваш заказ №${order.id} успешно создан',
        );
      } catch (e, st) {
        debugPrint('Order created notification failed: $e');
        debugPrintStack(stackTrace: st);
      }
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Заказ оформлен'),
            content: Text(
              'Ваш заказ №${order.id} успешно создан.\n'
              'Сумма: ${order.totalAmount.toStringAsFixed(2)} ₽',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ок'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      context.go('/orders-history');
    } catch (e) {
      final recoveredOrder = await _tryRecoverRecentlyCreatedOrder(
        expectedReceiveTime: receiveDateTime,
      );
      if (recoveredOrder != null) {
        if (!mounted) return;
        try {
          await LocalNotificationService.instance.showNow(
            id: recoveredOrder.id,
            title: 'Заказ оформлен',
            body: 'Ваш заказ №${recoveredOrder.id} успешно создан',
          );
        } catch (_) {}
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Заказ оформлен'),
              content: Text(
                'Ваш заказ №${recoveredOrder.id} успешно создан.\n'
                'Сумма: ${recoveredOrder.totalAmount.toStringAsFixed(2)} ₽',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Ок'),
                ),
              ],
            );
          },
        );
        if (!mounted) return;
        context.go('/orders-history');
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось оформить заказ.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<OrderModel?> _tryRecoverRecentlyCreatedOrder({
    required DateTime expectedReceiveTime,
  }) async {
    try {
      final orders = await AppDi.orderRepository.getOrders();
      if (orders.isEmpty) return null;

      final latest = orders.first;
      final createdAt = latest.createdAt;
      if (createdAt == null) return null;

      final now = DateTime.now();
      final isFresh = now.difference(createdAt).inMinutes.abs() <= 3;
      final sameReceiveTime =
          latest.receiveTime.difference(expectedReceiveTime).inMinutes.abs() <= 1;

      if (isFresh && sameReceiveTime) {
        return latest;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildPickupSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Способ получения',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: _pickupTypes.map((type) {
            final selected = _selectedPickupTypeId == type.id;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type.id == 1 ? 8 : 0,
                  left: type.id == 2 ? 8 : 0,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    setState(() {
                      _selectedPickupTypeId = type.id;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type.id == 1
                              ? Icons.delivery_dining_rounded
                              : Icons.storefront_rounded,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type.title,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPaymentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Способ оплаты',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: _paymentMethods.map((method) {
            final selected = _selectedPaymentMethodId == method.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _selectedPaymentMethodId = method.id;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        method.id == 1
                            ? Icons.payments_rounded
                            : method.id == 2
                                ? Icons.credit_card_rounded
                                : Icons.language_rounded,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          method.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Radio<int>(
                        value: method.id,
                        groupValue: _selectedPaymentMethodId,
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _selectedPaymentMethodId = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildOrderItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Состав заказа',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._cartItems.map(
          (item) {
            final dish = item.dish;
            final unitPrice = dish?.price ?? 0;
            final lineTotal = unitPrice * item.quantity;
            final options = item.selectedOptions?.trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: DishThumbnail(
                          photoPath: dish?.photoPath,
                          size: 52,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dish?.title ?? 'Блюдо №${item.dishId}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.quantity} × ${unitPrice.toStringAsFixed(2)} ₽',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (options != null && options.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                options,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        '${lineTotal.toStringAsFixed(2)} ₽',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    if (_selectedPickupTypeId != 1) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.storefront_rounded, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Самовывоз из ресторана. Адрес доставки не требуется.',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_addresses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'У вас нет сохранённых адресов. Добавьте адрес доставки, чтобы продолжить.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _openAddAddressSheet,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('Добавить адрес'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Text(
                'Адрес доставки',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _submitting ? null : _openAddAddressSheet,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Добавить'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._addresses.map(
          (address) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AddressCard(
              address: address,
              onSelect: () {
                setState(() {
                  _selectedAddressId = address.id;
                });
              },
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Оформление заказа'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Подготавливаем оформление...')
          : _isStaff
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Для ролей менеджер и администратор оформление заказов недоступно.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadCheckoutData,
                )
              : _cartItems.isEmpty
                  ? const Center(
                      child: Text(
                        'Корзина пуста',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        children: [
                          _buildPickupSelector(),
                          const SizedBox(height: 22),
                          _buildOrderItemsSection(),
                          const SizedBox(height: 22),
                          _buildAddressSection(),
                          const SizedBox(height: 22),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _receiveTimeController,
                                    readOnly: true,
                                    onTap: _pickReceiveTime,
                                    validator: (_) =>
                                        _selectedReceiveDateTime == null
                                            ? 'Выберите время'
                                            : null,
                                    decoration: InputDecoration(
                                      hintText: 'Слоты с 11:00 до 22:00',
                                      labelText:
                                          'Время доставки / самовывоза',
                                      suffixIcon: const Icon(
                                        Icons.access_time_rounded,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _commentController,
                                    maxLines: 3,
                                    maxLength: 300,
                                    validator: Validators.validateComment,
                                    decoration: const InputDecoration(
                                      hintText: 'Комментарий к заказу',
                                      labelText: 'Комментарий',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _buildPaymentSelector(),
                          const SizedBox(height: 22),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Бонусы',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Доступно бонусов: $_availableBonus',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _bonusController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: const InputDecoration(
                                      hintText: 'Сколько бонусов списать',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return null;
                                      }
                                      final baseValidation = Validators.validateOptionalPositiveInt(
                                        value,
                                        fieldName: 'бонусы',
                                        min: 0,
                                        max: 1000000,
                                      );
                                      if (baseValidation != null) {
                                        return baseValidation;
                                      }
                                      final parsed = int.parse(value.trim());
                                      if (parsed > _availableBonus) {
                                        return 'Недостаточно бонусов';
                                      }
                                      return null;
                                    },
                                    onChanged: (_) {
                                      setState(() {});
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _bonusController.text =
                                              _availableBonus.toString();
                                        });
                                      },
                                      child: const Text('Списать все'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  PriceRow(
                                    label: 'Товары',
                                    value:
                                        '${_itemsSubtotal.toStringAsFixed(2)} ₽',
                                  ),
                                  const SizedBox(height: 10),
                                  PriceRow(
                                    label: 'Доставка',
                                    value:
                                        '${_deliveryCost.toStringAsFixed(2)} ₽',
                                  ),
                                  const SizedBox(height: 10),
                                  PriceRow(
                                    label: 'Списание бонусов',
                                    value: '-${_spentBonus.toString()} ₽',
                                  ),
                                  const Divider(height: 28),
                                  PriceRow(
                                    label: 'Итого',
                                    value:
                                        '${_totalAmount.toStringAsFixed(2)} ₽',
                                    isTotal: true,
                                  ),
                                  const SizedBox(height: 18),
                                  PrimaryButton(
                                    text: 'Подтвердить заказ',
                                    isLoading: _submitting,
                                    onPressed: _submitOrder,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _PickupTypeItem {
  final int id;
  final String title;

  const _PickupTypeItem({
    required this.id,
    required this.title,
  });
}

class _PaymentMethodItem {
  final int id;
  final String title;

  const _PaymentMethodItem({
    required this.id,
    required this.title,
  });
}