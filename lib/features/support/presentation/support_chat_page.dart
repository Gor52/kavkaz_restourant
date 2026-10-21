import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/support_conversation_model.dart';
import '../../../data/models/support_message_model.dart';
import '../../../shared/enums/user_role.dart';

class SupportChatPage extends StatefulWidget {
  final int conversationId;

  const SupportChatPage({super.key, required this.conversationId});

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;

  SupportConversationModel? _conversation;
  List<SupportMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isActionLoading = false;
  String? _error;
  int? _myUserId;
  UserRole _myRole = UserRole.guest;

  bool get _isStaff => _myRole.isStaff;
  bool get _isClosed => _conversation?.isClosed == true;

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _isSending || _isLoading) return;
      _refreshSilently();
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final distance =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    return distance < 140;
  }

  String _formatMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return DateFormat('HH:mm', 'ru_RU').format(dateTime.toLocal());
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final me = await AppDi.profileRepository.getProfile();
      final roleTitle = await AppDi.sessionService.getRole();
      final payload = await AppDi.supportRepository.getMessages(
        widget.conversationId,
      );
      await AppDi.supportRepository.markRead(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _myUserId = me.id;
        _myRole = UserRole.fromTitle(roleTitle);
        _conversation = payload.conversation;
        _messages = payload.messages;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить сообщения.');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshSilently() async {
    try {
      final payload = await AppDi.supportRepository.getMessages(
        widget.conversationId,
      );
      await AppDi.supportRepository.markRead(widget.conversationId);
      if (!mounted) return;
      final shouldStickBottom = _isNearBottom();
      final oldCount = _messages.length;
      setState(() {
        _conversation = payload.conversation;
        _messages = payload.messages;
      });
      if (_messages.length != oldCount && shouldStickBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending || _isClosed) return;
    setState(() => _isSending = true);
    try {
      await AppDi.supportRepository.postMessage(
        conversationId: widget.conversationId,
        messageText: text,
      );
      _controller.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeError(e, fallback: 'Не удалось отправить сообщение.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _assignToMe() async {
    if (!_isStaff || _isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await AppDi.supportRepository.assignToMe(widget.conversationId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeError(e, fallback: 'Не удалось назначить диалог.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _closeConversation() async {
    if (!_isStaff || _isActionLoading) return;
    setState(() => _isActionLoading = true);
    try {
      await AppDi.supportRepository.closeConversation(widget.conversationId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeError(e, fallback: 'Не удалось закрыть диалог.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conv = _conversation;
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          _isStaff
              ? (conv?.userName?.trim().isNotEmpty == true
                  ? conv!.userName!.trim()
                  : 'Диалог #${widget.conversationId}')
              : 'Чат поддержки',
        ),
        actions:
            _isStaff
                ? [
                  if ((conv?.assignedStaffId == null ||
                          conv?.assignedStaffId != _myUserId) &&
                      !_isClosed)
                    IconButton(
                      tooltip: 'Взять в работу',
                      onPressed: _isActionLoading ? null : _assignToMe,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    ),
                  if (!_isClosed)
                    IconButton(
                      tooltip: 'Закрыть диалог',
                      onPressed: _isActionLoading ? null : _closeConversation,
                      icon: const Icon(Icons.lock_outline_rounded),
                    ),
                ]
                : null,
      ),
      body:
          _isLoading
              ? const LoadingView(message: 'Загружаем сообщения...')
              : _error != null
              ? ErrorState(
                title: 'Ошибка загрузки',
                subtitle: _error!,
                onRetry: _load,
              )
              : Column(
                children: [
                  if (_isClosed)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        'Диалог закрыт. Отправка новых сообщений недоступна.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  Expanded(
                    child:
                        _messages.isEmpty
                            ? const Center(
                              child: Text(
                                'Сообщений пока нет',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            )
                            : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                10,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final m = _messages[index];
                                final mine =
                                    _myUserId != null &&
                                    m.senderUserId == _myUserId;
                                return Align(
                                  alignment:
                                      mine
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.78,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          mine
                                              ? AppColors.primary.withValues(
                                                alpha: 0.15,
                                              )
                                              : AppColors.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!mine &&
                                            m.senderName != null &&
                                            m.senderName!.trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              m.senderName!.trim(),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          m.messageText,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (m.createdAt != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            _formatMessageTime(m.createdAt),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textHint,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              minLines: 1,
                              maxLines: 4,
                              enabled: !_isClosed && !_isSending,
                              decoration: const InputDecoration(
                                hintText: 'Введите сообщение...',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed:
                                (!_isClosed && !_isSending) ? _send : null,
                            child:
                                _isSending
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.send_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }
}
