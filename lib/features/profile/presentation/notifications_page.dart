import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/notification_tile.dart';
import '../../../data/models/notification_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _actionLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications =
          await AppDi.notificationRepository.getNotifications();

      if (!mounted) return;
      setState(() {
        _notifications = notifications;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(
          e,
          fallback: 'Не удалось загрузить уведомления.',
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

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;

    try {
      setState(() => _actionLoading = true);

      await AppDi.notificationRepository.markAsRead(notification.id);
      await _loadNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось отметить уведомление.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      setState(() => _actionLoading = true);

      await AppDi.notificationRepository.markAllAsRead();
      await _loadNotifications();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все уведомления отмечены как прочитанные')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось обновить уведомления.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  int get _unreadCount =>
      _notifications.where((item) => !item.isRead).length;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _actionLoading ? null : _markAllAsRead,
              child: const Text('Прочитать все'),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем уведомления...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadNotifications,
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_notifications.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withOpacity(0.12),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _unreadCount == 0
                                      ? 'Все уведомления прочитаны'
                                      : 'Непрочитанных уведомлений: $_unreadCount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_notifications.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              'Уведомлений пока нет',
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ..._notifications.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: NotificationTile(
                              notification: item,
                              onTap: _actionLoading
                                  ? null
                                  : () => _markAsRead(item),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}