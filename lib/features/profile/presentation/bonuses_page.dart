import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/bonus_operation_model.dart';

class BonusesPage extends StatefulWidget {
  const BonusesPage({super.key});

  @override
  State<BonusesPage> createState() => _BonusesPageState();
}

class _BonusesPageState extends State<BonusesPage> {
  List<BonusOperationModel> _operations = [];
  int _balance = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBonuses();
  }

  Future<void> _loadBonuses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final operations = await AppDi.profileRepository.getBonusHistory();
      final balance = await AppDi.profileRepository.getBonusBalance();

      if (!mounted) return;
      setState(() {
        _operations = operations;
        _balance = balance;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить бонусы.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Дата неизвестна';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Бонусы'),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем бонусы...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadBonuses,
                )
              : RefreshIndicator(
                  onRefresh: _loadBonuses,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryLight,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Текущий бонусный баланс',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_balance бонусов',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Бонусы можно использовать при оформлении заказа',
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'История операций',
                        style: TextStyle(
                          fontSize: 20,
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
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ..._operations.map(
                          (operation) => Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    operation.bonusOperationTypeId == 1
                                        ? Colors.green.withOpacity(0.12)
                                        : Colors.orange.withOpacity(0.12),
                                child: Icon(
                                  operation.bonusOperationTypeId == 1
                                      ? Icons.add
                                      : Icons.remove,
                                  color: operation.bonusOperationTypeId == 1
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                              title: Text(
                                operation.operationTitle ?? 'Операция',
                              ),
                              subtitle: Text(
                                operation.orderId != null
                                    ? 'Заказ №${operation.orderId} • ${_formatDate(operation.createdAt)}'
                                    : _formatDate(operation.createdAt),
                              ),
                              trailing: Text(
                                '${operation.bonusOperationTypeId == 1 ? '+' : '-'}${operation.bonusAmount}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: operation.bonusOperationTypeId == 1
                                      ? Colors.green
                                      : Colors.orange,
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