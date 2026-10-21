import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/booking_model.dart';

class AdminBookingsPage extends StatefulWidget {
  const AdminBookingsPage({super.key});

  @override
  State<AdminBookingsPage> createState() => _AdminBookingsPageState();
}

class _AdminBookingsPageState extends State<AdminBookingsPage> {
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String? _error;

  bool _isCanceledBooking(BookingModel booking) =>
      booking.bookingStatusId == 3 ||
      (booking.bookingStatusTitle ?? '').toLowerCase().contains('отмен');

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await AppDi.adminRepository.getAdminBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(
          e,
          fallback: 'Не удалось загрузить бронирования.',
        );
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeStatus(BookingModel booking) async {
    if (_isCanceledBooking(booking)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя изменить статус отмененного бронирования.')),
      );
      return;
    }

    int selectedStatus = booking.bookingStatusId;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text('Статус брони №${booking.id}'),
                  content: DropdownButtonFormField<int>(
                    value: selectedStatus,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Создано')),
                      DropdownMenuItem(value: 2, child: Text('Подтверждено')),
                      DropdownMenuItem(value: 3, child: Text('Отменено')),
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
      await AppDi.adminRepository.updateBookingStatus(
        bookingId: booking.id,
        bookingStatusId: selectedStatus,
      );
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось обновить статус бронирования.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Бронирования')),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем бронирования...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadBookings,
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final booking = _bookings[index];
                      final canChangeStatus = !_isCanceledBooking(booking);
                      final userName = (booking.userFullName ?? '').trim().isNotEmpty
                          ? booking.userFullName!.trim()
                          : 'Пользователь #${booking.userId}';
                      final userPhone = (booking.userPhone ?? '').trim().isNotEmpty
                          ? booking.userPhone!.trim()
                          : 'не указан';
                      final userEmail = (booking.userEmail ?? '').trim().isNotEmpty
                          ? booking.userEmail!.trim()
                          : 'не указан';
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.event_seat),
                          title: Text(
                            '${booking.bookingDate.day.toString().padLeft(2, '0')}.'
                            '${booking.bookingDate.month.toString().padLeft(2, '0')}.'
                            '${booking.bookingDate.year} ${booking.bookingTime}',
                          ),
                          subtitle: Text(
                            'Пользователь: $userName\n'
                            'Телефон: $userPhone\n'
                            'Email: $userEmail\n'
                            'Гостей: ${booking.guestCount}\n'
                            'Статус: ${booking.bookingStatusTitle ?? booking.bookingStatusId}',
                          ),
                          isThreeLine: false,
                          trailing: canChangeStatus
                              ? const Icon(Icons.edit_outlined)
                              : const Icon(Icons.lock_outline),
                          onTap: canChangeStatus ? () => _changeStatus(booking) : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}