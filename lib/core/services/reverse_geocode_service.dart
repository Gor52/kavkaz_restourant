import 'package:dio/dio.dart';

abstract final class ReverseGeocodeService {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {
        'User-Agent': 'KavkazRestaurantApp/1.0 (delivery address)',
        'Accept-Language': 'ru',
      },
    ),
  );

  static Future<String?> reverse(double latitude, double longitude) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude&accept-language=ru',
      );
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      final data = response.data;
      if (data == null) return null;
      final name = data['display_name'];
      return name is String ? name : null;
    } catch (_) {
      return null;
    }
  }
}
