import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/category_model.dart';
import '../../../shared/enums/user_role.dart';

class AdminCategoriesPage extends StatefulWidget {
  const AdminCategoriesPage({super.key});

  @override
  State<AdminCategoriesPage> createState() => _AdminCategoriesPageState();
}

class _AdminCategoriesPageState extends State<AdminCategoriesPage> {
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String? _error;
  UserRole _role = UserRole.guest;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roleTitle = await AppDi.sessionService.getRole();
      final categories = await AppDi.adminRepository.getAdminCategories();
      if (!mounted) return;
      setState(() {
        _role = UserRole.fromTitle(roleTitle);
        _categories = categories;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить категории.');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCategory(CategoryModel category) async {
    try {
      await AppDi.adminRepository.deleteCategory(category.id);
      await _loadCategories();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось удалить категорию.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManageCategories = _role.isAdmin;
    return AppScaffold(
      appBar: AppBar(title: const Text('Категории')),
      floatingActionButton: canManageCategories
          ? FloatingActionButton(
              onPressed: () => context.push('/admin/categories/form'),
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const LoadingView(message: 'Загружаем категории...')
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadCategories,
                )
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final category = _categories[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withOpacity(0.1),
                            child: const Icon(
                              Icons.category_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(category.title),
                          subtitle: Text('Порядок: ${category.sortOrder}'),
                          trailing: PopupMenuButton<String>(
                            enabled: canManageCategories,
                            onSelected: (value) {
                              if (value == 'edit') {
                                context
                                    .push('/admin/categories/form', extra: category)
                                    .then((_) => _loadCategories());
                              } else if (value == 'delete') {
                                _deleteCategory(category);
                              }
                            },
                            itemBuilder: (_) => canManageCategories
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