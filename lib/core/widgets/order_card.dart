import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/order_model.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;
  final VoidCallback? onRepeat;
  final VoidCallback? onCancel;
  final VoidCallback? onEdit;

  const OrderCard({
    super.key,
    required this.order,
    this.onTap,
    this.onRepeat,
    this.onCancel,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Заказ №${order.id}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Text(
                        order.orderStatusTitle ?? 'Статус',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Получение: ${order.pickupTypeTitle ?? '-'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Оплата: ${order.paymentMethodTitle ?? '-'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if ((order.userFullName ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Клиент: ${order.userFullName!.trim()}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if ((order.userPhone ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Телефон: ${order.userPhone!.trim()}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if ((order.userEmail ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Email: ${order.userEmail!.trim()}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Сумма: ${order.totalAmount.toStringAsFixed(2)} ₽',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.start,
                children: [
                  TextButton(onPressed: onTap, child: const Text('Подробнее')),
                  if (onEdit != null) TextButton(onPressed: onEdit, child: const Text('Изменить')),
                  TextButton(onPressed: onRepeat, child: const Text('Повторить')),
                  if (onCancel != null)
                    TextButton(onPressed: onCancel, child: const Text('Отменить')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}