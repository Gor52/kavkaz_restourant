import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/bonus_operation_model.dart';
import '../../../data/models/user_model.dart';

class AdminUserBonusHistoryPage extends StatefulWidget {
  final UserModel user;

  const AdminUserBonusHistoryPage({
    super.key,
    required this.user,
  });

  @override
  State<AdminUserBonusHistoryPage> createState() => _AdminUserBonusHistoryPageState();
}

class _AdminUserBonusHistoryPageState extends State<AdminUserBonusHistoryPage> {
  List<BonusOperationModel> _operations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final operations = await AppDi.adminRepository.getUserBonusHistory(widget.user.id);
      if (!mounted) return;
      setState(() {
        _operations = operations;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить историю бонусов.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Дата неизвестна';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text('Бонусы: ${widget.user.fullName}')),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем историю бонусов...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadHistory,
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        'Текущий баланс: ${widget.user.bonusBalance}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_operations.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Center(
                            child: Text(
                              'История бонусных операций пуста',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ..._operations.map(
                          (operation) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: operation.bonusOperationTypeId == 1
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : Colors.orange.withValues(alpha: 0.12),
                                child: Icon(
                                  operation.bonusOperationTypeId == 1 ? Icons.add : Icons.remove,
                                  color: operation.bonusOperationTypeId == 1 ? Colors.green : Colors.orange,
                                ),
                              ),
                              title: Text(operation.operationTitle ?? 'Операция'),
                              subtitle: Text(
                                operation.orderId != null
                                    ? 'Заказ №${operation.orderId} • ${_formatDate(operation.createdAt)}'
                                    : _formatDate(operation.createdAt),
                              ),
                              trailing: Text(
                                '${operation.bonusOperationTypeId == 1 ? '+' : '-'}${operation.bonusAmount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: operation.bonusOperationTypeId == 1 ? Colors.green : Colors.orange,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
