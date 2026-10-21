import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/di.dart';
import '../../data/models/notification_model.dart';
import 'local_notification_service.dart';

class InAppNotificationSyncService {
  InAppNotificationSyncService._();

  static final InAppNotificationSyncService instance =
      InAppNotificationSyncService._();

  Timer? _timer;
  bool _started = false;
  bool _syncing = false;
  final Set<int> _knownNotificationIds = <int>{};
  bool _baselineSeeded = false;
  DateTime? _sessionAnchorUtc;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _sync(silent: true);
    _timer = Timer.periodic(const Duration(seconds: 12), (_) {
      _sync(silent: true);
    });
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  /// Call after successful login / register so new server notifications
  /// (e.g. orders while logging in) are not swallowed by the first baseline fetch.
  void recordSessionStart() {
    _sessionAnchorUtc = DateTime.now().toUtc();
    _baselineSeeded = false;
    _knownNotificationIds.clear();
  }

  void resetAfterLogout() {
    _sessionAnchorUtc = null;
    _baselineSeeded = false;
    _knownNotificationIds.clear();
  }

  Future<void> refresh() => _sync(silent: true);

  bool _isFreshForSession(NotificationModel item, DateTime anchorUtc) {
    final created = item.createdAt;
    if (created == null) return true;
    return !created.isBefore(anchorUtc.subtract(const Duration(seconds: 3)));
  }

  Future<void> _sync({required bool silent}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final authorized = await AppDi.sessionService.isAuthorized();
      if (!authorized) return;

      final notifications =
          await AppDi.notificationRepository.getNotifications();

      if (!_baselineSeeded) {
        _sessionAnchorUtc ??= DateTime.now().toUtc();
        final anchor = _sessionAnchorUtc!;

        for (final item in notifications) {
          _knownNotificationIds.add(item.id);
          if (!item.isRead && _isFreshForSession(item, anchor)) {
            await _showNotification(item);
          }
        }
        _baselineSeeded = true;
        return;
      }

      for (final item in notifications) {
        final inserted = _knownNotificationIds.add(item.id);
        if (!inserted || item.isRead) continue;
        await _showNotification(item);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[InAppNotificationSync] $e\n$st');
      }
      if (!silent) rethrow;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _showNotification(NotificationModel item) async {
    await LocalNotificationService.instance.showNow(
      id: item.id,
      title: item.title,
      body: item.text,
    );
  }
}
