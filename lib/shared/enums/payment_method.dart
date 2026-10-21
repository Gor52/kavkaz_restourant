enum PaymentMethod {
  cash,
  card,
  online;

  static PaymentMethod fromTitle(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'наличными':
        return PaymentMethod.cash;
      case 'банковской картой':
        return PaymentMethod.card;
      case 'онлайн-оплата':
        return PaymentMethod.online;
      default:
        return PaymentMethod.cash;
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return 'Наличными';
      case PaymentMethod.card:
        return 'Банковской картой';
      case PaymentMethod.online:
        return 'Онлайн-оплата';
    }
  }
}