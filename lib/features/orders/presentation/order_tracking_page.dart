import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';

class OrderTrackingPage extends StatelessWidget {
  final int orderId;
  final String status;

  const OrderTrackingPage({
    super.key,
    required this.orderId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Новый',
      'Подтвержден',
      'Готовится',
      'Готов',
      'Доставляется',
      'Завершен',
    ];

    final currentIndex = steps.indexOf(status).clamp(0, steps.length - 1);

    return AppScaffold(
      appBar: AppBar(
        title: Text('Статус заказа №$orderId'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: steps.length,
        itemBuilder: (_, index) {
          final isActive = index <= currentIndex;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        isActive ? AppColors.primary : AppColors.border,
                    child: Icon(
                      Icons.check,
                      size: 16,
                      color: isActive ? Colors.white : AppColors.textHint,
                    ),
                  ),
                  if (index != steps.length - 1)
                    Container(
                      width: 2,
                      height: 48,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  steps[index],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}