import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../app/di.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/dish_model.dart';

class AdminDishFormPage extends StatefulWidget {
  const AdminDishFormPage({super.key, this.initialDish});

  final DishModel? initialDish;

  @override
  State<AdminDishFormPage> createState() => _AdminDishFormPageState();
}

class _AdminDishFormPageState extends State<AdminDishFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _priceController = TextEditingController();
  final _weightController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _allergensController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isAvailable = true;
  int? _selectedCategoryId;
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  bool _isLoadingCategories = true;
  String? _categoriesError;
  List<CategoryModel> _categories = [];
  File? _pickedPhotoFile;
  final _priceInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*[.,]?\d{0,2}$'),
  );

  bool get _isEditMode => widget.initialDish != null;

  @override
  void initState() {
    super.initState();
    final dish = widget.initialDish;
    if (dish != null) {
      _selectedCategoryId = dish.categoryId;
    }

    if (dish != null) {
      _titleController.text = dish.title;
      _descriptionController.text = dish.description;
      _ingredientsController.text = dish.ingredients;
      _priceController.text = dish.price.toStringAsFixed(2);
      _weightController.text = dish.weight.toString();
      _caloriesController.text = dish.calories?.toString() ?? '';
      _allergensController.text = dish.allergens ?? '';
      _photoUrlController.text = dish.photoPath ?? '';
      _isAvailable = dish.isAvailable;
    }

    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
    });

    try {
      final categories = await AppDi.adminRepository.getAdminCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (_categories.isEmpty) {
          _selectedCategoryId = null;
          return;
        }
        final hasSelected = _selectedCategoryId != null &&
            _categories.any((c) => c.id == _selectedCategoryId);
        _selectedCategoryId = hasSelected ? _selectedCategoryId : _categories.first.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _categoriesError = humanizeError(
          e,
          fallback: 'Не удалось загрузить категории.',
        );
      });
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final price = double.parse(_priceController.text.trim().replaceAll(',', '.'));
    final weight = int.parse(_weightController.text.trim());
    final calories = _caloriesController.text.trim().isEmpty
        ? null
        : int.parse(_caloriesController.text.trim());
    final selectedCategoryId = _selectedCategoryId;
    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите категорию')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final allergens = _allergensController.text.trim().isEmpty
          ? null
          : _allergensController.text.trim();
      final photoPath = _photoUrlController.text.trim().isEmpty
          ? null
          : _photoUrlController.text.trim();

      final dish = widget.initialDish;
      if (dish == null) {
        await AppDi.adminRepository.createDish(
          categoryId: selectedCategoryId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          ingredients: _ingredientsController.text.trim(),
          price: price,
          weight: weight,
          calories: calories,
          allergens: allergens,
          photoPath: photoPath,
          isAvailable: _isAvailable,
        );
      } else {
        await AppDi.adminRepository.updateDish(
          dishId: dish.id,
          categoryId: selectedCategoryId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          ingredients: _ingredientsController.text.trim(),
          price: price,
          weight: weight,
          calories: calories,
          allergens: allergens,
          photoPath: photoPath,
          isAvailable: _isAvailable,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Блюдо обновлено' : 'Блюдо создано'),
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось сохранить блюдо.'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickPhotoFromPhoneStorage() async {
    if (_isUploadingPhoto || _isSubmitting) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1920,
      );
      if (picked == null) return;
      final file = File(picked.path);
      if (!mounted) return;
      setState(() {
        _pickedPhotoFile = file;
        _isUploadingPhoto = true;
      });
      final uploadedUrl = await AppDi.adminRepository.uploadDishPhoto(file);
      if (!mounted) return;
      setState(() {
        _photoUrlController.text = uploadedUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Фото загружено и привязано к блюду')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось загрузить фото.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Widget _buildPhotoPreview() {
    if (_pickedPhotoFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _pickedPhotoFile!,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }
    final url = _photoUrlController.text.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPhotoPlaceholder(),
        ),
      );
    }
    return _buildPhotoPlaceholder();
  }

  Widget _buildPhotoPlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 36,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать блюдо' : 'Новое блюдо'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              AppTextField(
                controller: _titleController,
                hintText: 'Название блюда',
                validator: Validators.validateDishTitle,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _descriptionController,
                hintText: 'Описание',
                maxLines: 3,
                maxLength: 500,
                validator: (value) => Validators.validateDishText(
                  value,
                  fieldName: 'описание',
                  maxLength: 500,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _ingredientsController,
                hintText: 'Состав',
                maxLines: 3,
                maxLength: 300,
                validator: (value) => Validators.validateDishText(
                  value,
                  fieldName: 'состав',
                  maxLength: 300,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _priceController,
                hintText: 'Цена',
                keyboardType: TextInputType.number,
                inputFormatters: [_priceInputFormatter],
                validator: (value) => Validators.validatePositiveDecimal(
                  value,
                  fieldName: 'цена',
                  min: 0.01,
                  max: 1000000,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _weightController,
                hintText: 'Вес',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) => Validators.validatePositiveInt(
                  value,
                  fieldName: 'вес',
                  min: 1,
                  max: 100000,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _caloriesController,
                hintText: 'Калорийность',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) => Validators.validateOptionalPositiveInt(
                  value,
                  fieldName: 'калорийность',
                  min: 1,
                  max: 10000,
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: _allergensController,
                hintText: 'Аллергены',
                maxLength: 200,
              ),
              const SizedBox(height: 14),
              _buildPhotoPreview(),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isUploadingPhoto ? null : _pickPhotoFromPhoneStorage,
                icon: _isUploadingPhoto
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined),
                label: Text(
                  _isUploadingPhoto
                      ? 'Загрузка фото...'
                      : 'Выбрать фото из памяти телефона',
                ),
              ),
              const SizedBox(height: 10),
              AppTextField(
                controller: _photoUrlController,
                hintText: 'Ссылка на фото (заполняется автоматически)',
                maxLength: 500,
                validator: Validators.validateOptionalUrl,
              ),
              const SizedBox(height: 14),
              if (_isLoadingCategories)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else if (_categoriesError != null)
                Text(
                  _categoriesError!,
                  style: const TextStyle(color: Colors.red),
                )
              else
                DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Категория',
                  ),
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.title),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                  validator: (value) => value == null ? 'Выберите категорию' : null,
                ),
              const SizedBox(height: 14),
              SwitchListTile(
                value: _isAvailable,
                onChanged: (value) {
                  setState(() {
                    _isAvailable = value;
                  });
                },
                title: const Text('Доступно к заказу'),
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