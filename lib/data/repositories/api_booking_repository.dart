import '../models/booking_model.dart';
import '../sources/remote/api_service.dart';

class ApiBookingRepository {
  final ApiService _apiService;

  ApiBookingRepository(this._apiService);

  Future<List<BookingModel>> getBookings() async {
    final response = await _apiService.get<List<dynamic>>('/bookings');

    return (response.data ?? [])
        .map((item) => BookingModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<BookingModel> createBooking({
    required String bookingDate,
    required String bookingTime,
    required int guestCount,
    String? comment,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/bookings',
      data: {
        'booking_date': bookingDate,
        'booking_time': bookingTime,
        'guest_count': guestCount,
        'comment': comment,
      },
    );

    if (response.data == null) {
      throw Exception('Не удалось создать бронь');
    }

    return BookingModel.fromJson(response.data!);
  }

  Future<BookingModel> updateBooking({
    required int bookingId,
    required String bookingDate,
    required String bookingTime,
    required int guestCount,
    String? comment,
  }) async {
    final response = await _apiService.put<Map<String, dynamic>>(
      '/bookings/$bookingId',
      data: {
        'booking_date': bookingDate,
        'booking_time': bookingTime,
        'guest_count': guestCount,
        'comment': comment,
      },
    );

    if (response.data == null) {
      throw Exception('Не удалось обновить бронь');
    }

    return BookingModel.fromJson(response.data!);
  }

  Future<void> cancelBooking(int bookingId) async {
    await _apiService.delete<void>('/bookings/$bookingId');
  }
}
