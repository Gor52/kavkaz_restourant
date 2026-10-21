enum UserRole {
  guest,
  user,
  manager,
  admin;

  bool get isAdmin => this == UserRole.admin;
  bool get isManager => this == UserRole.manager;
  bool get isStaff => isAdmin || isManager;
  bool get isAuthorized => this != UserRole.guest;

  static UserRole fromTitle(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'пользователь':
        return UserRole.user;
      case 'менеджер':
        return UserRole.manager;
      case 'администратор':
        return UserRole.admin;
      default:
        return UserRole.guest;
    }
  }
}