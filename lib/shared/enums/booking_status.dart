enum BookingStatus {
  newBooking,
  confirmed,
  cancelled,
  completed;

  static BookingStatus fromTitle(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'новый':
        return BookingStatus.newBooking;
      case 'подтвержден':
        return BookingStatus.confirmed;
      case 'отменен':
        return BookingStatus.cancelled;
      case 'завершен':
        return BookingStatus.completed;
      default:
        return BookingStatus.newBooking;
    }
  }

  String get label {
    switch (this) {
      case BookingStatus.newBooking:
        return 'Новый';
      case BookingStatus.confirmed:
        return 'Подтвержден';
      case BookingStatus.cancelled:
        return 'Отменен';
      case BookingStatus.completed:
        return 'Завершен';
    }
  }
}