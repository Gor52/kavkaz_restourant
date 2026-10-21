import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/enums/user_role.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  bool _actionLoading = false;
  String? _error;
  UserRole _role = UserRole.guest;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roleTitle = await AppDi.sessionService.getRole();
      final uid = await AppDi.sessionService.getUserId();
      final users = await AppDi.adminRepository.getUsers();
      if (!mounted) return;
      setState(() {
        _role = UserRole.fromTitle(roleTitle);
        _currentUserId = uid;
        _users = users;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(
          e,
          fallback: 'Не удалось загрузить пользователей.',
        );
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _roleTitle(int roleId) {
    switch (roleId) {
      case 1:
        return 'Пользователь';
      case 2:
        return 'Менеджер';
      case 3:
        return 'Администратор';
      default:
        return 'Неизвестно';
    }
  }

  Future<void> _changeRole(UserModel user) async {
    int selectedRoleId = user.roleId;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: const Text('Изменить роль'),
                  content: DropdownButtonFormField<int>(
                    value: selectedRoleId,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('Пользователь')),
                      DropdownMenuItem(value: 2, child: Text('Менеджер')),
                      DropdownMenuItem(value: 3, child: Text('Администратор')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedRoleId = value ?? 1;
                      });
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Сохранить'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      setState(() => _actionLoading = true);
      await AppDi.adminRepository.updateUserRole(
        userId: user.id,
        roleId: selectedRoleId,
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось изменить роль пользователя.'))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _deleteUser(UserModel user) async {
    if (_currentUserId != null && user.id == _currentUserId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя удалить свою учётную запись.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить пользователя?'),
            content: Text('Удалить ${user.fullName} (${user.phone})?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    try {
      setState(() => _actionLoading = true);
      await AppDi.adminRepository.deleteUser(user.id);
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь удалён')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось удалить пользователя.'))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _toggleBlock(UserModel user) async {
    try {
      setState(() => _actionLoading = true);
      await AppDi.adminRepository.blockUser(
        user.id,
        isBlocked: !user.isBlocked,
      );
      await _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось изменить статус пользователя.'))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _adjustBonus(UserModel user) async {
    final amountController = TextEditingController();
    final commentController = TextEditingController();
    String operationType = 'accrual';

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: Text('Бонусы: ${user.fullName}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Текущий баланс: ${user.bonusBalance}'),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(value: 'accrual', label: Text('Начислить')),
                          ButtonSegment<String>(value: 'writeoff', label: Text('Списать')),
                          ButtonSegment<String>(value: 'set_balance', label: Text('Установить баланс')),
                        ],
                        selected: {operationType},
                        onSelectionChanged: (value) {
                          setDialogState(() {
                            operationType = value.first;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'set_balance: целевой баланс, иначе: количество',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: commentController,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий (необязательно)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Отмена'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Применить'),
                  ),
                ],
              ),
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите корректное количество бонусов.')),
      );
      return;
    }

    try {
      setState(() => _actionLoading = true);
      final result = await AppDi.adminRepository.adjustUserBonus(
        userId: user.id,
        operationType: operationType,
        bonusAmount: amount,
        comment: commentController.text.trim().isEmpty ? null : commentController.text.trim(),
      );
      await _loadUsers();
      if (!mounted) return;
      final balanceAfter = result['balance_after'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${operationType == 'accrual'
                ? 'Начислено'
                : operationType == 'writeoff'
                    ? 'Списано'
                    : 'Баланс скорректирован'} $amount бонусов. '
            'Новый баланс: ${balanceAfter ?? 'обновлен'}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось изменить бонусы пользователя.'))),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
      amountController.dispose();
      commentController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageUsers = _role.isAdmin;
    final canManageBonuses = _role.isStaff;
    return AppScaffold(
      appBar: AppBar(title: const Text('Пользователи')),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем пользователей...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadUsers,
                )
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final user = _users[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.person_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(user.fullName),
                          subtitle: Text(
                            '${user.phone}\n${_roleTitle(user.roleId)}\nБонусы: ${user.bonusBalance}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            enabled: (canManageUsers || canManageBonuses) && !_actionLoading,
                            onSelected: (value) {
                              if (value == 'bonus') {
                                _adjustBonus(user);
                              } else if (value == 'bonus_history') {
                                context.push('/admin/users/bonus-history', extra: user);
                              } else if (value == 'role') {
                                _changeRole(user);
                              } else if (value == 'block') {
                                _toggleBlock(user);
                              } else if (value == 'delete') {
                                _deleteUser(user);
                              }
                            },
                            itemBuilder: (_) {
                              final items = <PopupMenuEntry<String>>[];
                              if (canManageBonuses) {
                                items.add(
                                  const PopupMenuItem(
                                    value: 'bonus',
                                    child: Text('Управлять бонусами'),
                                  ),
                                );
                                items.add(
                                  const PopupMenuItem(
                                    value: 'bonus_history',
                                    child: Text('История бонусов'),
                                  ),
                                );
                              }
                              if (canManageUsers) {
                                items.addAll([
                                    const PopupMenuItem(
                                      value: 'role',
                                      child: Text('Изменить роль'),
                                    ),
                                    PopupMenuItem(
                                      value: 'block',
                                      child: Text(
                                        user.isBlocked
                                            ? 'Разблокировать'
                                            : 'Заблокировать',
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Удалить'),
                                    ),
                                  ]);
                              }
                              return items;
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}