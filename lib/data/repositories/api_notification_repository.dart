import '../models/notification_model.dart';
import '../sources/remote/api_service.dart';

class ApiNotificationRepository {
  final ApiService _apiService;

  ApiNotificationRepository(this._apiService);

  Future<List<NotificationModel>> getNotifications() async {
    final response = await _apiService.get<List<dynamic>>('/notifications');

    return (response.data ?? [])
        .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(int notificationId) async {
    await _apiService.put<void>('/notifications/$notificationId/read');
  }

  Future<void> markAllAsRead() async {
    await _apiService.put<void>('/notifications/read-all');
  }

  Future<void> sendToUser({
    required int userId,
    required String title,
    required String text,
  }) async {
    await _apiService.post<dynamic>(
      '/notifications/send',
      data: {
        'user_id': userId,
        'title': title,
        'text': text,
      },
    );
  }
}
