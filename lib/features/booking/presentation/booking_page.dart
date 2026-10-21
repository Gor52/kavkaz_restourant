import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../app/di.dart';
import '../../../app/auth_required_navigation.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/local_notification_service.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/booking_card.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/booking_model.dart';
import '../../../shared/enums/user_role.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _guestCountController =
      TextEditingController(text: '2');
  final TextEditingController _commentController = TextEditingController();

  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  bool _submitting = false;
  String? _error;
  bool _isAuthorized = false;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _guestCountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await AppDi.bookingRepository.getBookings();

      if (!mounted) return;
      setState(() {
        _bookings = bookings;
      });
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        await AppDi.sessionService.clearSession();
        if (!mounted) return;
        context.go(buildAuthRequiredLocation(from: '/booking'));
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = humanizeError(
          e,
          fallback: 'Не удалось загрузить бронирования.',
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

  Future<void> _initPage() async {
    final role = UserRole.fromTitle(await AppDi.sessionService.getRole());
    setState(() {
      _isAuthorized = true;
      _isStaff = role.isStaff;
    });
    await _loadBookings();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      locale: const Locale('ru', 'RU'),
    );

    if (selected != null) {
      _dateController.text = selected.toIso8601String().split('T').first;
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 19, minute: 0),
    );

    if (selected != null) {
      final hh = selected.hour.toString().padLeft(2, '0');
      final mm = selected.minute.toString().padLeft(2, '0');
      _timeController.text = '$hh:$mm:00';
    }
  }

  Future<void> _createBooking() async {
    if (_isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Для менеджера и администратора создание бронирования недоступно',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final guestCount = int.parse(_guestCountController.text.trim());

      await AppDi.bookingRepository.createBooking(
        bookingDate: _dateController.text.trim(),
        bookingTime: _timeController.text.trim(),
        guestCount: guestCount,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );

      _dateController.clear();
      _timeController.clear();
      _guestCountController.text = '2';
      _commentController.clear();

      await _loadBookings();

      if (!mounted) return;
      await LocalNotificationService.instance.showNow(
        title: 'Бронь создана',
        body: 'Бронирование успешно оформлено',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Бронирование успешно создано')),
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        await AppDi.sessionService.clearSession();
        if (!mounted) return;
        context.go(buildAuthRequiredLocation(from: '/booking'));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось создать бронирование.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _cancelBooking(BookingModel booking) async {
    try {
      await AppDi.bookingRepository.cancelBooking(booking.id);
      await _loadBookings();

      if (!mounted) return;
      await LocalNotificationService.instance.showNow(
        id: booking.id,
        title: 'Бронь отменена',
        body: 'Бронирование №${booking.id} отменено',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Бронирование №${booking.id} отменено')),
      );
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        await AppDi.sessionService.clearSession();
        if (!mounted) return;
        context.go(buildAuthRequiredLocation(from: '/booking'));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось отменить бронирование.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && !_isAuthorized) {
      return AppScaffold(
        appBar: AppBar(
          title: const Text('Бронирование'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 44,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Бронирование доступно после входа',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(
                  text: 'Войти',
                  onPressed: () => context.push('/login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Бронирование'),
      ),
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
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: _isStaff
                              ? const Text(
                                  'Для ролей менеджер и администратор бронирование недоступно.',
                                  style: TextStyle(color: AppColors.textSecondary),
                                )
                              : Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                TextFormField(
                                  controller: _dateController,
                                  readOnly: true,
                                  onTap: _pickDate,
                                  validator: Validators.validateRequired,
                                  decoration: const InputDecoration(
                                    hintText: 'Выберите дату',
                                    labelText: 'Дата',
                                    suffixIcon: Icon(
                                      Icons.calendar_month_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _timeController,
                                  readOnly: true,
                                  onTap: _pickTime,
                                  validator: Validators.validateRequired,
                                  decoration: const InputDecoration(
                                    hintText: 'Выберите время',
                                    labelText: 'Время',
                                    suffixIcon: Icon(
                                      Icons.access_time_rounded,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _guestCountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) => Validators.validatePositiveInt(
                                    value,
                                    fieldName: 'количество гостей',
                                    min: 1,
                                    max: 30,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Количество гостей',
                                    labelText: 'Гости',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _commentController,
                                  maxLines: 3,
                                  maxLength: 300,
                                  validator: Validators.validateComment,
                                  decoration: const InputDecoration(
                                    hintText: 'Комментарий',
                                    labelText: 'Комментарий',
                                  ),
                                ),
                                const SizedBox(height: 18),
                                PrimaryButton(
                                  text: 'Забронировать',
                                  isLoading: _submitting,
                                  onPressed: _createBooking,
                                ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Мои бронирования',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_bookings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Center(
                            child: Text(
                              'У вас пока нет бронирований',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._bookings.map(
                          (booking) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: BookingCard(
                              booking: booking,
                              onTap: null,
                              onEdit: null,
                              onCancel: () => _cancelBooking(booking),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}