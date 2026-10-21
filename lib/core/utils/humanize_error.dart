String humanizeError(
  Object error, {
  String fallback = 'Что-то пошло не так. Попробуйте еще раз.',
}) {
  var raw = error.toString().trim();
  if (raw.isEmpty) return fallback;

  const prefixes = ['Exception:', 'DioException:', 'PostgrestException:'];
  for (final prefix in prefixes) {
    if (raw.startsWith(prefix)) {
      raw = raw.substring(prefix.length).trim();
      break;
    }
  }

  final lower = raw.toLowerCase();

  if (lower.contains('invalid credentials')) {
    return 'Неверный логин или пароль.';
  }
  if (lower.contains('login is required')) {
    return 'Введите логин.';
  }
  if (lower.contains('user already exists')) {
    return 'Пользователь с такими данными уже существует.';
  }
  if (lower.contains('account is blocked') ||
      lower.contains('аккаунт заблокирован')) {
    return 'Ваш аккаунт заблокирован. Обратитесь в поддержку.';
  }
  if (lower.contains('internal server error')) {
    return 'Сервис временно недоступен. Попробуйте немного позже.';
  }
  if (lower.contains('route not found')) {
    return 'Страница или раздел не найдены.';
  }
  if (lower.contains('invalid order id') ||
      lower.contains('invalid booking id') ||
      lower.contains('invalid review id') ||
      lower.contains('invalid dish id') ||
      lower.contains('invalid user id') ||
      lower.contains('invalid address id')) {
    return 'Переданы некорректные данные запроса.';
  }
  if (lower.contains('order not found')) {
    return 'Заказ не найден.';
  }
  if (lower.contains('booking not found')) {
    return 'Бронирование не найдено.';
  }
  if (lower.contains('review not found')) {
    return 'Отзыв не найден.';
  }
  if (lower.contains('менеджер и администратор не могут оставлять отзывы')) {
    return 'Менеджер и администратор не могут оставлять отзывы.';
  }
  if (lower.contains('dish not found')) {
    return 'Блюдо не найдено.';
  }
  if (lower.contains('address not found')) {
    return 'Адрес не найден.';
  }
  if (lower.contains('user not found')) {
    return 'Пользователь не найден.';
  }
  if (lower.contains('notification not found')) {
    return 'Уведомление не найдено.';
  }
  if (lower.contains('диалог не найден') ||
      lower.contains('conversation not found')) {
    return 'Диалог поддержки не найден.';
  }
  if (lower.contains('диалог закрыт')) {
    return 'Диалог закрыт. Создайте новое обращение.';
  }
  if (lower.contains('cart item not found')) {
    return 'Позиция корзины не найдена.';
  }
  if (lower.contains('dish_id is required')) {
    return 'Выберите блюдо, для которого хотите открыть отзывы.';
  }
  if (lower.contains('date_from must be <= date_to')) {
    return 'Дата начала периода не может быть позже даты окончания.';
  }
  if (lower.contains('unsupported import_type') ||
      lower.contains('unsupported export_type')) {
    return 'Выбран неподдерживаемый тип операции.';
  }
  if (lower.contains('unique constraint violation')) {
    return 'Такая запись уже существует.';
  }
  if (lower.contains('файл изображения не передан')) {
    return 'Выберите изображение и повторите попытку.';
  }
  if (lower.contains('не удалось загрузить изображение')) {
    return 'Не удалось загрузить изображение. Проверьте формат файла.';
  }
  if (lower.contains('почтовый сервер не настроен')) {
    return 'Почтовый сервис временно недоступен. Попробуйте позже.';
  }

  if (lower.contains('socket') ||
      lower.contains('network') ||
      lower.contains('connection') ||
      lower.contains('timed out') ||
      lower.contains('timeout')) {
    return 'Проблема с интернетом. Проверьте подключение и попробуйте еще раз.';
  }
  if (lower.contains('401') || lower.contains('не авторизован')) {
    return 'Нужно заново войти в аккаунт.';
  }
  if (lower.contains('403') || lower.contains('доступ запрещ')) {
    return 'Недостаточно прав для этого действия.';
  }
  if (lower.contains('404') || lower.contains('не найден')) {
    return 'Нужные данные не найдены.';
  }
  if (lower.contains('409') ||
      lower.contains('foreign key') ||
      lower.contains('violates foreign key constraint') ||
      lower.contains('is still referenced') ||
      lower.contains('update or delete on table') ||
      lower.contains('constraint')) {
    return 'Эта запись используется в других данных и не может быть удалена.';
  }
  if (lower.contains('500') ||
      lower.contains('502') ||
      lower.contains('503') ||
      lower.contains('server') ||
      lower.contains('сервер')) {
    return 'Сервис временно недоступен. Попробуйте немного позже.';
  }
  if (lower.contains('корзина пуста')) {
    return 'Корзина пуста. Добавьте блюда и попробуйте снова.';
  }
  if (lower.contains('неверный логин')) {
    return 'Проверьте логин и пароль и попробуйте снова.';
  }
  if (lower.contains('current password is incorrect')) {
    return 'Текущий пароль введен неверно.';
  }
  if (lower.contains('заказ уже нельзя отменить')) {
    return 'Этот заказ уже нельзя отменить.';
  }
  if (lower.contains('нельзя редактировать отмененное бронирование')) {
    return 'Нельзя изменить отмененное бронирование.';
  }
  if (lower.contains('некоторые блюда недоступны')) {
    return 'Некоторые блюда сейчас недоступны. Обновите корзину.';
  }
  if (lower.contains('адрес обязателен для доставки')) {
    return 'Укажите адрес доставки.';
  }
  if (lower.contains('недостаточно бонусов')) {
    return 'Недостаточно бонусов для списания.';
  }
  if (lower.contains('можно списать не более')) {
    return 'Превышен допустимый лимит списания бонусов.';
  }
  if (lower.contains('заблокирован')) {
    return 'Ваш аккаунт временно заблокирован. Обратитесь в поддержку.';
  }
  if (lower.contains('код недействителен') || lower.contains('истек')) {
    return 'Код недействителен или истек. Запросите новый код.';
  }
  if (lower.contains('is required') ||
      lower.contains('must be') ||
      lower.contains('fails to match') ||
      lower.contains('not allowed to be empty')) {
    return 'Проверьте заполнение полей формы.';
  }
  if (lower.contains('format') || lower.contains('формат')) {
    return 'Не удалось обработать данные. Проверьте ввод и повторите попытку.';
  }

  if (raw.length > 180) return fallback;
  return raw;
}
