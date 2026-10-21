enum OrderStatus {
  newOrder,
  confirmed,
  cooking,
  ready,
  delivering,
  completed,
  cancelled;

  static OrderStatus fromTitle(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'новый':
        return OrderStatus.newOrder;
      case 'подтвержден':
        return OrderStatus.confirmed;
      case 'готовится':
        return OrderStatus.cooking;
      case 'готов':
        return OrderStatus.ready;
      case 'доставляется':
        return OrderStatus.delivering;
      case 'завершен':
        return OrderStatus.completed;
      case 'отменен':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.newOrder;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.newOrder:
        return 'Новый';
      case OrderStatus.confirmed:
        return 'Подтвержден';
      case OrderStatus.cooking:
        return 'Готовится';
      case OrderStatus.ready:
        return 'Готов';
      case OrderStatus.delivering:
        return 'Доставляется';
      case OrderStatus.completed:
        return 'Завершен';
      case OrderStatus.cancelled:
        return 'Отменен';
    }
  }

  bool get blocksNewOrder {
    switch (this) {
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return false;
      default:
        return true;
    }
  }

  bool get canCustomerCancel => this == OrderStatus.newOrder;
}