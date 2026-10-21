abstract final class Validators {
  static String? validateRequired(
    String? value, {
    String message = 'Поле обязательно для заполнения',
  }) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите имя';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 50) {
      return 'Имя должно содержать от 2 до 50 символов';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите номер телефона';
    }
    final trimmed = value.trim();
    final regex = RegExp(r'^\+?[0-9()\-\s]{5,20}$');
    if (!regex.hasMatch(trimmed)) {
      return 'Введите корректный номер телефона';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    final regex = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );
    if (!regex.hasMatch(trimmed)) {
      return 'Введите корректный email';
    }
    return null;
  }

  static String? validateRequiredEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите email';
    }
    return validateEmail(value);
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 6 || value.length > 50) {
      return 'Пароль должен содержать от 6 до 50 символов';
    }
    return null;
  }

  static String? validatePasswordWithStrength(String? value) {
    final base = validatePassword(value);
    if (base != null) return base;
    final v = value!;
    if (!RegExp(r'^(?=.*[A-Za-zА-Яа-яЁё])(?=.*\d).+$').hasMatch(v)) {
      return 'Пароль должен содержать хотя бы одну букву и одну цифру';
    }
    return null;
  }

  static String? validateAddressComment(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (value.trim().length > 200) {
      return 'Комментарий не должен превышать 200 символов';
    }
    return null;
  }

  static String? validateLogin(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите телефон или email';
    }
    final trimmed = value.trim();
    if (trimmed.contains('@')) {
      final emailRegex = RegExp(
        r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
      );
      if (!emailRegex.hasMatch(trimmed)) {
        return 'Введите корректный номер телефона или почту';
      }
      return null;
    }
    final phoneRegex = RegExp(r'^\+?[0-9()\-\s]{5,20}$');
    if (!phoneRegex.hasMatch(trimmed)) {
      return 'Введите корректный номер телефона или почту';
    }
    return null;
  }

  static String? validateRecoveryCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите код восстановления';
    }
    final trimmed = value.trim();
    final regex = RegExp(r'^[A-Za-z0-9_-]{4,64}$');
    if (!regex.hasMatch(trimmed)) {
      return 'Код должен содержать 4-64 символа: буквы, цифры, - или _';
    }
    return null;
  }

  static String? validateCategoryTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите название категории';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 80) {
      return 'Название категории должно быть от 2 до 80 символов';
    }
    return null;
  }

  static String? validateDishTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите название блюда';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 120) {
      return 'Название блюда должно быть от 2 до 120 символов';
    }
    return null;
  }

  static String? validateDishText(
    String? value, {
    required String fieldName,
    int maxLength = 500,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите $fieldName';
    }
    final trimmed = value.trim();
    if (trimmed.length > maxLength) {
      return '$fieldName не должен превышать $maxLength символов';
    }
    return null;
  }

  static String? validatePositiveInt(
    String? value, {
    required String fieldName,
    int min = 1,
    int max = 1000000,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите $fieldName';
    }
    final number = int.tryParse(value.trim());
    if (number == null) {
      return '$fieldName должен быть целым числом';
    }
    if (number < min || number > max) {
      return '$fieldName должен быть в диапазоне $min-$max';
    }
    return null;
  }

  static String? validateOptionalPositiveInt(
    String? value, {
    required String fieldName,
    int min = 1,
    int max = 1000000,
  }) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return validatePositiveInt(value, fieldName: fieldName, min: min, max: max);
  }

  static String? validatePositiveDecimal(
    String? value, {
    required String fieldName,
    double min = 0.01,
    double max = 1000000,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите $fieldName';
    }
    final normalized = value.trim().replaceAll(',', '.');
    final number = double.tryParse(normalized);
    if (number == null) {
      return '$fieldName должен быть числом';
    }
    if (number < min || number > max) {
      return '$fieldName должен быть в диапазоне $min-$max';
    }
    return null;
  }

  static String? validateOptionalUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Введите корректную ссылку';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Ссылка должна начинаться с http:// или https://';
    }
    return null;
  }

  static String? validateOptionalText(
    String? value, {
    required String fieldName,
    int maxLength = 300,
  }) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.length > maxLength) {
      return '$fieldName не должен превышать $maxLength символов';
    }
    return null;
  }

  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите адрес';
    }
    if (value.trim().length > 200) {
      return 'Адрес не должен превышать 200 символов';
    }
    return null;
  }

  static String? validateComment(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (value.trim().length > 300) {
      return 'Комментарий не должен превышать 300 символов';
    }
    return null;
  }

  static String? validateReview(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Введите текст отзыва';
    }
    final length = value.trim().length;
    if (length < 1 || length > 500) {
      return 'Отзыв должен содержать от 1 до 500 символов';
    }
    return null;
  }
}