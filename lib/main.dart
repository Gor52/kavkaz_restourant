import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/services/in_app_notification_sync_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/session_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SessionService.onSessionCleared = () {
    InAppNotificationSyncService.instance.resetAfterLogout();
  };
  await LocalNotificationService.instance.initialize();
  await InAppNotificationSyncService.instance.start();
  runApp(const CaucasianRestaurantApp());
}
