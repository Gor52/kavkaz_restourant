import '../../core/services/session_service.dart';
import '../models/address_model.dart';
import '../models/bonus_operation_model.dart';
import '../models/user_model.dart';
import '../sources/remote/api_service.dart';

class ApiProfileRepository {
  final ApiService _apiService;
  final SessionService _sessionService;

  ApiProfileRepository(this._apiService, this._sessionService);

  Future<UserModel> getProfile() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/profile',
    );

    if (response.data == null) {
      throw Exception('Профиль не найден');
    }

    return UserModel.fromJson(response.data!);
  }

  Future<UserModel> updateProfile({
    required String fullName,
    required String phone,
    String? email,
    String? confirmPassword,
  }) async {
    final data = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      'email': email,
    };
    if (confirmPassword != null && confirmPassword.isNotEmpty) {
      data['confirm_password'] = confirmPassword;
    }

    final response = await _apiService.put<Map<String, dynamic>>(
      '/profile',
      data: data,
    );

    if (response.data == null) {
      throw Exception('Не удалось обновить профиль');
    }

    return UserModel.fromJson(response.data!);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiService.put<void>(
      '/profile/password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<void> deleteAccount() async {
    await _apiService.delete<void>('/profile');
    await _sessionService.clearSession();
  }

  Future<List<AddressModel>> getAddresses() async {
    final response = await _apiService.get<List<dynamic>>('/profile/addresses');

    return (response.data ?? [])
        .map((item) => AddressModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AddressModel> addAddress({
    required String addressText,
    String? comment,
    bool isDefault = false,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/profile/addresses',
      data: {
        'address_text': addressText,
        'comment': comment,
        'is_default': isDefault,
      },
    );

    if (response.data == null) {
      throw Exception('Не удалось добавить адрес');
    }

    return AddressModel.fromJson(response.data!);
  }

  Future<AddressModel> updateAddress({
    required int addressId,
    required String addressText,
    String? comment,
    bool isDefault = false,
  }) async {
    final response = await _apiService.put<Map<String, dynamic>>(
      '/profile/addresses/$addressId',
      data: {
        'address_text': addressText,
        'comment': comment,
        'is_default': isDefault,
      },
    );

    if (response.data == null) {
      throw Exception('Не удалось обновить адрес');
    }

    return AddressModel.fromJson(response.data!);
  }

  Future<void> deleteAddress(int addressId) async {
    await _apiService.delete<void>('/profile/addresses/$addressId');
  }

  Future<List<BonusOperationModel>> getBonusHistory() async {
    final response = await _apiService.get<List<dynamic>>('/profile/bonus-history');

    return (response.data ?? [])
        .map((item) => BonusOperationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<int> getBonusBalance() async {
    final response = await _apiService.get<Map<String, dynamic>>('/profile/bonus-balance');
    return (response.data?['bonus_balance'] as num?)?.toInt() ?? 0;
  }
}
