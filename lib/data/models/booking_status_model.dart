class BookingStatusModel {
  final int id;
  final String title;

  const BookingStatusModel({
    required this.id,
    required this.title,
  });

  factory BookingStatusModel.fromJson(Map<String, dynamic> json) {
    return BookingStatusModel(
      id: json['id_booking_status'] as int,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_booking_status': id,
      'title': title,
    };
  }
}