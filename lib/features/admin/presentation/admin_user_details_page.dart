import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/primary_button.dart';

class AdminUserDetailsPage extends StatefulWidget {
  const AdminUserDetailsPage({super.key});

  @override
  State<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage> {
  int _roleId = 1;
  bool _isBlocked = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Пользователь'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Иван Петров'),
                    SizedBox(height: 8),
                    Text('+79001112233'),
                    SizedBox(height: 8),
                    Text('ivan@mail.ru'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _roleId,
              decoration: const InputDecoration(
                labelText: 'Роль пользователя',
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('Пользователь')),
                DropdownMenuItem(value: 2, child: Text('Менеджер')),
                DropdownMenuItem(value: 3, child: Text('Администратор')),
              ],
              onChanged: (value) {
                setState(() {
                  _roleId = value ?? 1;
                });
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isBlocked,
              onChanged: (value) {
                setState(() {
                  _isBlocked = value;
                });
              },
              title: const Text('Пользователь заблокирован'),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: 'Сохранить',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}