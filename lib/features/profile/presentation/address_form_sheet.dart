import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/address_model.dart';
import 'address_map_picker_page.dart';

Future<AddressModel?> showAddressFormSheet(
  BuildContext context, {
  AddressModel? existing,
}) {
  return showModalBottomSheet<AddressModel?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => AddressFormSheet(existing: existing),
  );
}

class AddressFormSheet extends StatefulWidget {
  const AddressFormSheet({super.key, this.existing});

  final AddressModel? existing;

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;
  late final TextEditingController _commentController;
  late bool _isDefault;
  double? _pickedLat;
  double? _pickedLng;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _addressController = TextEditingController(text: e?.addressText ?? '');
    _commentController = TextEditingController(text: e?.comment ?? '');
    _isDefault = e?.isDefault ?? false;
  }

  @override
  void dispose() {
    _addressController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _openMap() async {
    final r = await Navigator.of(context).push<AddressMapPickerResult>(
      MaterialPageRoute<AddressMapPickerResult>(
        fullscreenDialog: true,
        builder: (_) => AddressMapPickerPage(
          initialLatitude: _pickedLat,
          initialLongitude: _pickedLng,
        ),
      ),
    );
    if (!mounted || r == null) return;
    setState(() {
      _pickedLat = r.latitude;
      _pickedLng = r.longitude;
      final hint = r.suggestedAddress?.trim();
      if (_addressController.text.trim().isEmpty &&
          hint != null &&
          hint.isNotEmpty) {
        _addressController.text = hint;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final e = widget.existing;
      final addr = _addressController.text.trim();
      final rawComment = _commentController.text.trim();
      final commentOpt = rawComment.isEmpty ? null : rawComment;

      final AddressModel saved;
      if (e == null) {
        saved = await AppDi.profileRepository.addAddress(
          addressText: addr,
          comment: commentOpt,
          isDefault: _isDefault,
        );
      } else {
        saved = await AppDi.profileRepository.updateAddress(
          addressId: e.id,
          addressText: addr,
          comment: commentOpt,
          isDefault: _isDefault,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            humanizeError(err, fallback: 'Не удалось сохранить адрес.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final ime = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: ime),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.existing == null
                      ? 'Новый адрес доставки'
                      : 'Редактировать адрес',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _addressController,
                  validator: Validators.validateAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Адрес доставки',
                    hintText: 'Улица, дом, подъезд',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _commentController,
                  maxLines: 3,
                  maxLength: 200,
                  validator: Validators.validateAddressComment,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    hintText: 'Домофон, этаж',
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _openMap,
                  icon: const Icon(Icons.map_rounded),
                  label: Text(
                    _pickedLat != null && _pickedLng != null
                        ? 'Точка на карте выбрана'
                        : 'Указать на карте',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Карта подставляет адрес в поле выше; в базе хранится только текст.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                CheckboxListTile(
                  value: _isDefault,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() => _isDefault = v ?? false),
                  title: const Text('Адрес по умолчанию'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _submitting ? null : () => Navigator.pop(context),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _save,
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
