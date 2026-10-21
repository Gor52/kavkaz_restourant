import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/category_model.dart';

class AdminCategoryFormPage extends StatefulWidget {
  const AdminCategoryFormPage({super.key, this.initialCategory});

  final CategoryModel? initialCategory;

  @override
  State<AdminCategoryFormPage> createState() => _AdminCategoryFormPageState();
}

class _AdminCategoryFormPageState extends State<AdminCategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sortOrderController = TextEditingController();
  bool _isSubmitting = false;

  bool get _isEditMode => widget.initialCategory != null;

  @override
  void initState() {
    super.initState();
    final category = widget.initialCategory;
    if (category == null) return;
    _titleController.text = category.title;
    _sortOrderController.text = category.sortOrder.toString();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sortOrder = int.parse(_sortOrderController.text.trim());

    setState(() => _isSubmitting = true);
    try {
      final category = widget.initialCategory;
      if (category == null) {
        await AppDi.adminRepository.createCategory(
          title: _titleController.text.trim(),
          sortOrder: sortOrder,
        );
      } else {
        await AppDi.adminRepository.updateCategory(
          categoryId: category.id,
          title: _titleController.text.trim(),
          sortOrder: sortOrder,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Категория обновлена' : 'Категория создана'),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось сохранить категорию.'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать категорию' : 'Новая категория'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              AppTextField(
                controller: _titleController,
                hintText: 'Название категории',
                validator: Validators.validateCategoryTitle,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _sortOrderController,
                hintText: 'Порядок сортировки',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) => Validators.validatePositiveInt(
                  value,
                  fieldName: 'порядок сортировки',
                  min: 1,
                  max: 100000,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: _isSubmitting
                    ? 'Сохранение...'
                    : (_isEditMode ? 'Сохранить изменения' : 'Сохранить'),
                onPressed: _isSubmitting ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}