import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/dish_thumbnail.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/dish_model.dart';
import '../../../shared/enums/user_role.dart';

class AdminDishesPage extends StatefulWidget {
  const AdminDishesPage({super.key});

  @override
  State<AdminDishesPage> createState() => _AdminDishesPageState();
}

class _AdminDishesPageState extends State<AdminDishesPage> {
  List<DishModel> _dishes = [];
  bool _isLoading = true;
  String? _error;
  UserRole _role = UserRole.guest;

  @override
  void initState() {
    super.initState();
    _loadDishes();
  }

  Future<void> _loadDishes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roleTitle = await AppDi.sessionService.getRole();
      final dishes = await AppDi.adminRepository.getAdminDishes();
      if (!mounted) return;
      setState(() {
        _role = UserRole.fromTitle(roleTitle);
        _dishes = dishes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить блюда.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDish(DishModel dish) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить блюдо?'),
            content: Text(
              'Блюдо "${dish.title}" будет удалено из меню.\n\n'
              'Важно: в истории заказов это блюдо может отображаться некорректно '
              '(например без названия), особенно для старых заказов.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await AppDi.adminRepository.deleteDish(dish.id);
      await _loadDishes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось удалить блюдо.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageMenu = _role.isAdmin;
    return AppScaffold(
      appBar: AppBar(title: const Text('Управление меню')),
      floatingActionButton: canManageMenu
          ? FloatingActionButton(
              onPressed: () => context.push('/admin/dishes/form'),
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const LoadingView(message: 'Загружаем блюда...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadDishes,
                )
              : RefreshIndicator(
                  onRefresh: _loadDishes,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _dishes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final dish = _dishes[index];
                      return Card(
                        child: ListTile(
                          leading: DishThumbnail(
                            photoPath: dish.photoPath,
                            size: 52,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          title: Text(dish.title),
                          subtitle: Text(
                            '${dish.price.toStringAsFixed(2)} ₽ • ${dish.weight} г',
                          ),
                          trailing: PopupMenuButton<String>(
                            enabled: canManageMenu,
                            onSelected: (value) {
                              if (value == 'edit') {
                                context
                                    .push('/admin/dishes/form', extra: dish)
                                    .then((_) => _loadDishes());
                              } else if (value == 'delete') {
                                _deleteDish(dish);
                              }
                            },
                            itemBuilder: (_) => canManageMenu
                                ? const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Редактировать'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Удалить'),
                                    ),
                                  ]
                                : const [],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}