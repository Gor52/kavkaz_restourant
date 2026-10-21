import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/support_conversation_model.dart';
import '../../../shared/enums/user_role.dart';

class SupportConversationsPage extends StatefulWidget {
  const SupportConversationsPage({super.key});

  @override
  State<SupportConversationsPage> createState() =>
      _SupportConversationsPageState();
}

class _SupportConversationsPageState extends State<SupportConversationsPage> {
  List<SupportConversationModel> _conversations = [];
  bool _isLoading = true;
  String? _error;
  UserRole _role = UserRole.guest;

  bool get _isStaff => _role.isStaff;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final roleTitle = await AppDi.sessionService.getRole();
      final items = await AppDi.supportRepository.getConversations();
      if (!mounted) return;
      setState(() {
        _role = UserRole.fromTitle(roleTitle);
        _conversations = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(
          e,
          fallback: 'Не удалось загрузить чат поддержки.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createConversation() async {
    try {
      final conversation = await AppDi.supportRepository.createConversation();
      if (!mounted) return;
      context
          .push('/support/chat', extra: conversation.id)
          .then((_) => _load());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeError(e, fallback: 'Не удалось открыть диалог.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(_isStaff ? 'Обращения поддержки' : 'Чат поддержки'),
        actions: [
          if (!_isStaff)
            IconButton(
              tooltip: 'Новый диалог',
              onPressed: _createConversation,
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ],
      ),
      body:
          _isLoading
              ? const LoadingView(message: 'Загружаем диалоги...')
              : _error != null
              ? ErrorState(
                title: 'Ошибка загрузки',
                subtitle: _error!,
                onRetry: _load,
              )
              : RefreshIndicator(
                onRefresh: _load,
                child:
                    _conversations.isEmpty
                        ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 40),
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 52,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isStaff
                                  ? 'Пока нет обращений от пользователей.'
                                  : 'У вас пока нет диалогов с поддержкой.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (!_isStaff) ...[
                              const SizedBox(height: 16),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: _createConversation,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Открыть диалог'),
                                ),
                              ),
                            ],
                          ],
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                          itemCount: _conversations.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _conversations[index];
                            final title =
                                _isStaff
                                    ? (item.userName?.trim().isNotEmpty == true
                                        ? item.userName!.trim()
                                        : 'Пользователь #${item.userId}')
                                    : (item.assignedStaffName
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                        ? 'Сотрудник: ${item.assignedStaffName!.trim()}'
                                        : 'Поддержка');
                            return Material(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                onTap: () {
                                  context
                                      .push('/support/chat', extra: item.id)
                                      .then((_) => _load());
                                },
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  item.lastMessageText?.trim().isNotEmpty ==
                                          true
                                      ? item.lastMessageText!.trim()
                                      : (item.subject?.trim().isNotEmpty == true
                                          ? item.subject!.trim()
                                          : (item.isClosed
                                              ? 'Диалог закрыт'
                                              : 'Сообщений пока нет')),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing:
                                    item.unreadCount > 0
                                        ? CircleAvatar(
                                          radius: 12,
                                          backgroundColor: AppColors.primary,
                                          child: Text(
                                            '${item.unreadCount}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                        : Icon(
                                          item.isClosed
                                              ? Icons.lock_outline_rounded
                                              : Icons.chevron_right_rounded,
                                          color: AppColors.textHint,
                                        ),
                              ),
                            );
                          },
                        ),
              ),
    );
  }
}
