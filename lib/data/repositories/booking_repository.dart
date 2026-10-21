import 'package:postgres/postgres.dart';

import '../../app/di.dart';
import '../models/booking_model.dart';
import '../sources/remote/postgres_service.dart';

class BookingRepository {
  final PostgresService _postgresService;

  BookingRepository(this._postgresService);

  Future<List<BookingModel>> getBookings() async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        SELECT
          b.id_booking,
          b.user_id,
          b.booking_date,
          b.booking_time,
          b.guest_count,
          b.comment,
          b.booking_status_id,
          b.created_at,
          bs.title AS booking_status_title
        FROM bookings b
        JOIN booking_statuses bs ON bs.id_booking_status = b.booking_status_id
        WHERE b.user_id = @user_id
        ORDER BY b.id_booking DESC
      '''),
      parameters: {
        'user_id': userId,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();
      return BookingModel(
        id: data['id_booking'] as int,
        userId: data['user_id'] as int,
        bookingDate: data['booking_date'] as DateTime,
        bookingTime: data['booking_time'].toString(),
        guestCount: data['guest_count'] as int,
        comment: data['comment'] as String?,
        bookingStatusId: data['booking_status_id'] as int,
        bookingStatusTitle: data['booking_status_title'] as String?,
        createdAt: data['created_at'] as DateTime?,
      );
    }).toList();
  }

  Future<BookingModel> createBooking({
    required String bookingDate,
    required String bookingTime,
    required int guestCount,
    String? comment,
  }) async {
    final userId = await AppDi.sessionService.getUserId();
    if (userId == null) {
      throw Exception('Пользователь не авторизован');
    }

    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        INSERT INTO bookings (
          user_id,
          booking_date,
          booking_time,
          guest_count,
          comment,
          booking_status_id
        )
        VALUES (
          @user_id,
          @booking_date,
          @booking_time,
          @guest_count,
          @comment,
          1
        )
        RETURNING
          id_booking,
          user_id,
          booking_date,
          booking_time,
          guest_count,
          comment,
          booking_status_id,
          created_at
      '''),
      parameters: {
        'user_id': userId,
        'booking_date': DateTime.parse(bookingDate),
        'booking_time': bookingTime,
        'guest_count': guestCount,
        'comment': comment,
      },
    );

    final data = result.first.toColumnMap();

    return BookingModel(
      id: data['id_booking'] as int,
      userId: data['user_id'] as int,
      bookingDate: data['booking_date'] as DateTime,
      bookingTime: data['booking_time'].toString(),
      guestCount: data['guest_count'] as int,
      comment: data['comment'] as String?,
      bookingStatusId: data['booking_status_id'] as int,
      bookingStatusTitle: 'Новый',
      createdAt: data['created_at'] as DateTime?,
    );
  }

  Future<BookingModel> updateBooking({
    required int bookingId,
    required String bookingDate,
    required String bookingTime,
    required int guestCount,
    String? comment,
  }) async {
    final conn = await _postgresService.connection;

    final result = await conn.execute(
      Sql.named(r'''
        UPDATE bookings
        SET booking_date = @booking_date,
            booking_time = @booking_time,
            guest_count = @guest_count,
            comment = @comment
        WHERE id_booking = @booking_id
        RETURNING
          id_booking,
          user_id,
          booking_date,
          booking_time,
          guest_count,
          comment,
          booking_status_id,
          created_at
      '''),
      parameters: {
        'booking_date': DateTime.parse(bookingDate),
        'booking_time': bookingTime,
        'guest_count': guestCount,
        'comment': comment,
        'booking_id': bookingId,
      },
    );

    final data = result.first.toColumnMap();

    return BookingModel(
      id: data['id_booking'] as int,
      userId: data['user_id'] as int,
      bookingDate: data['booking_date'] as DateTime,
      bookingTime: data['booking_time'].toString(),
      guestCount: data['guest_count'] as int,
      comment: data['comment'] as String?,
      bookingStatusId: data['booking_status_id'] as int,
      createdAt: data['created_at'] as DateTime?,
    );
  }

  Future<void> cancelBooking(int bookingId) async {
    final conn = await _postgresService.connection;

    await conn.execute(
      Sql.named(r'''
        UPDATE bookings
        SET booking_status_id = 3
        WHERE id_booking = @booking_id
      '''),
      parameters: {
        'booking_id': bookingId,
      },
    );
  }
}