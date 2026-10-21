import 'package:postgres/postgres.dart';

import '../../app/di.dart';
import '../models/notification_model.dart';
import '../sources/remote/postgres_service.dart';

class NotificationRepository {
  final PostgresService _postgresService;

  NotificationRepository(this._postgresService);

  Future<List<NotificationModel>> getNotifications() async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        SELECT
          id_notification,
          user_id,
          title,
          text,
          is_read,
          created_at
        FROM notifications
        WHERE user_id = @user_id
        ORDER BY id_notification DESC
      '''),
      parameters: {
        'user_id': userId,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();
      return NotificationModel(
        id: data['id_notification'] as int,
        userId: data['user_id'] as int,
        title: data['title'] as String,
        text: data['text'] as String,
        isRead: data['is_read'] as bool? ?? false,
        createdAt: data['created_at'] as DateTime,
      );
    }).toList();
  }

  Future<void> markAsRead(int notificationId) async {
    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        UPDATE notifications
        SET is_read = TRUE
        WHERE id_notification = @notification_id
      '''),
      parameters: {
        'notification_id': notificationId,
      },
    );
  }

  Future<void> markAllAsRead() async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        UPDATE notifications
        SET is_read = TRUE
        WHERE user_id = @user_id
      '''),
      parameters: {
        'user_id': userId,
      },
    );
  }
}