import '../models/support_conversation_model.dart';
import '../models/support_message_model.dart';
import '../sources/remote/api_service.dart';

class SupportMessagesPayload {
  final SupportConversationModel conversation;
  final List<SupportMessageModel> messages;

  const SupportMessagesPayload({
    required this.conversation,
    required this.messages,
  });
}

class ApiSupportRepository {
  final ApiService _apiService;

  ApiSupportRepository(this._apiService);

  Future<List<SupportConversationModel>> getConversations() async {
    final response = await _apiService.get<List<dynamic>>(
      '/support/conversations',
    );
    return (response.data ?? [])
        .map(
          (item) =>
              SupportConversationModel.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<SupportConversationModel> createConversation({String? subject}) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/support/conversations',
      data: {'subject': subject},
    );
    if (response.data == null) {
      throw Exception('Не удалось создать диалог');
    }
    return SupportConversationModel.fromJson(response.data!);
  }

  Future<SupportMessagesPayload> getMessages(int conversationId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/support/conversations/$conversationId/messages',
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Не удалось загрузить сообщения');
    }
    final conversationRaw = data['conversation'] as Map<String, dynamic>?;
    final messagesRaw = data['messages'] as List<dynamic>? ?? const [];
    if (conversationRaw == null) {
      throw Exception('Диалог не найден');
    }
    return SupportMessagesPayload(
      conversation: SupportConversationModel.fromJson(conversationRaw),
      messages:
          messagesRaw
              .map(
                (item) =>
                    SupportMessageModel.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
    );
  }

  Future<SupportMessageModel> postMessage({
    required int conversationId,
    required String messageText,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/support/conversations/$conversationId/messages',
      data: {'message_text': messageText},
    );
    if (response.data == null) {
      throw Exception('Не удалось отправить сообщение');
    }
    return SupportMessageModel.fromJson(response.data!);
  }

  Future<void> markRead(int conversationId) async {
    await _apiService.put<void>('/support/conversations/$conversationId/read');
  }

  Future<void> assignToMe(int conversationId) async {
    await _apiService.put<void>(
      '/support/conversations/$conversationId/assign-to-me',
    );
  }

  Future<void> closeConversation(int conversationId) async {
    await _apiService.put<void>('/support/conversations/$conversationId/close');
  }
}
