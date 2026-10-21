import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/booking_model.dart';
import '../../shared/enums/booking_status.dart';

class BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;

  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.onEdit,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final status = BookingStatus.fromTitle(booking.bookingStatusTitle);
    final canCancel =
        status != BookingStatus.cancelled && status != BookingStatus.completed;

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
                  const Icon(Icons.event_seat_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Бронирование №${booking.id}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
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
                    child: Text(
                      booking.bookingStatusTitle ?? 'Статус',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Дата: ${booking.bookingDate.toLocal().toString().split(' ').first}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Время: ${booking.bookingTime}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                'Гостей: ${booking.guestCount}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: onEdit,
                    child: const Text('Изменить'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: canCancel ? onCancel : null,
                    child: const Text('Отменить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}