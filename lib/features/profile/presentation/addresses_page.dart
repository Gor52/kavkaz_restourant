import 'package:flutter/material.dart';

import '../../../app/di.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/address_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/address_model.dart';
import '../../../shared/enums/user_role.dart';
import 'address_form_sheet.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  List<AddressModel> _addresses = [];
  bool _isLoading = true;
  bool _actionLoading = false;
  String? _error;
  bool _isStaff = false;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final roleTitle = await AppDi.sessionService.getRole();
      final addresses = await AppDi.profileRepository.getAddresses();

      if (!mounted) return;
      setState(() {
        _isStaff = UserRole.fromTitle(roleTitle).isStaff;
        _addresses = addresses;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = humanizeError(e, fallback: 'Не удалось загрузить адреса.');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddressSheet({AddressModel? address}) async {
    if (_isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Для менеджера и администратора адреса доставки недоступны',
          ),
        ),
      );
      return;
    }

    setState(() => _actionLoading = true);
    try {
      final saved = await showAddressFormSheet(context, existing: address);
      if (!mounted) return;
      if (saved != null) {
        await _loadAddresses();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              address == null ? 'Адрес добавлен' : 'Адрес обновлен',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _deleteAddress(AddressModel address) async {
    if (_isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Для менеджера и администратора адреса доставки недоступны',
          ),
        ),
      );
      return;
    }
    try {
      setState(() => _actionLoading = true);

      await AppDi.profileRepository.deleteAddress(address.id);
      await _loadAddresses();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Адрес удален')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось удалить адрес.'))),
      );
    } finally {
      if (mounted) {
        setState(() => _actionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Адреса доставки'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _actionLoading || _isStaff ? null : () => _showAddressSheet(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const LoadingView(message: 'Загружаем адреса...')
          : _isStaff
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Для ролей менеджер и администратор управление адресами доставки недоступно.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
          : _error != null
              ? ErrorState(
                  title: 'Ошибка загрузки',
                  subtitle: _error!,
                  onRetry: _loadAddresses,
                )
              : RefreshIndicator(
                  onRefresh: _loadAddresses,
                  child: _addresses.isEmpty
                      ?  ListView(
                          children: [
                            SizedBox(height: 120),
                            Center(
                              child: Text(
                                'У вас нет сохраненных адресов',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _addresses.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, index) {
                            final address = _addresses[index];
                            return AddressCard(
                              address: address,
                              onEdit: _actionLoading
                                  ? null
                                  : () => _showAddressSheet(address: address),
                              onDelete: _actionLoading
                                  ? null
                                  : () => _deleteAddress(address),
                              onSelect: null,
                            );
                          },
                        ),
                ),
    );
  }
}