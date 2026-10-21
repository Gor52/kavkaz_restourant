class BookingModel {
  final int id;
  final int userId;
  final String? userFullName;
  final String? userPhone;
  final String? userEmail;
  final DateTime bookingDate;
  final String bookingTime;
  final int guestCount;
  final String? comment;
  final int bookingStatusId;
  final String? bookingStatusTitle;
  final DateTime? createdAt;

  const BookingModel({
    required this.id,
    required this.userId,
    this.userFullName,
    this.userPhone,
    this.userEmail,
    required this.bookingDate,
    required this.bookingTime,
    required this.guestCount,
    this.comment,
    required this.bookingStatusId,
    this.bookingStatusTitle,
    this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id_booking'] as int,
      userId: json['user_id'] as int,
      userFullName: json['user_full_name'] as String?,
      userPhone: json['user_phone'] as String?,
      userEmail: json['user_email'] as String?,
      bookingDate: DateTime.parse(json['booking_date'].toString()),
      bookingTime: json['booking_time'].toString(),
      guestCount: json['guest_count'] as int,
      comment: json['comment'] as String?,
      bookingStatusId: json['booking_status_id'] as int,
      bookingStatusTitle: json['booking_status_title'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_booking': id,
      'user_id': userId,
      'user_full_name': userFullName,
      'user_phone': userPhone,
      'user_email': userEmail,
      'booking_date': bookingDate.toIso8601String(),
      'booking_time': bookingTime,
      'guest_count': guestCount,
      'comment': comment,
      'booking_status_id': bookingStatusId,
      'booking_status_title': bookingStatusTitle,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}