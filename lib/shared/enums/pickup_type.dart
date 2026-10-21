enum PickupType {
  delivery,
  pickup;

  static PickupType fromTitle(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'доставка':
        return PickupType.delivery;
      case 'самовывоз':
        return PickupType.pickup;
      default:
        return PickupType.delivery;
    }
  }

  String get label {
    switch (this) {
      case PickupType.delivery:
        return 'Доставка';
      case PickupType.pickup:
        return 'Самовывоз';
    }
  }
}