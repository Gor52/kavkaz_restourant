import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/di.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';

class AdminImportPage extends StatefulWidget {
  const AdminImportPage({super.key});

  @override
  State<AdminImportPage> createState() => _AdminImportPageState();
}

class _AdminImportPageState extends State<AdminImportPage> {
  String _importType = 'Импорт меню';
  final _fileController = TextEditingController();
  final _payloadController = TextEditingController();
  final _commentController = TextEditingController();
  dynamic _parsedPayloadRoot;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fileController.dispose();
    _payloadController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _mapImportType(String value) {
    switch (value) {
      case 'Импорт категорий':
        return 'categories';
      case 'Импорт блюд':
        return 'dishes';
      default:
        return 'menu';
    }
  }

  Future<void> _pickAndParseFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final fileName = file.name;
      var extension = file.extension?.toLowerCase();
      if (extension == null || extension.isEmpty) {
        final n = fileName.toLowerCase();
        if (n.endsWith('.csv')) {
          extension = 'csv';
        } else if (n.endsWith('.json')) {
          extension = 'json';
        }
      }
      final fileBytes = file.bytes;

      if (fileBytes == null || fileBytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось прочитать файл')),
        );
        return;
      }

      final content = utf8.decode(fileBytes, allowMalformed: true).trim();
      if (content.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл пустой')),
        );
        return;
      }

      final payloadRoot = extension == 'csv'
          ? _parseCsvPayload(content)
          : _parseJsonPayload(content);

      if (payloadRoot is List && payloadRoot.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('В файле нет валидных данных для импорта')),
        );
        return;
      }
      if (payloadRoot is Map) {
        final cats = payloadRoot['categories'];
        final dishes = payloadRoot['dishes'];
        final hasCats = cats is List && cats.isNotEmpty;
        final hasDishes = dishes is List && dishes.isNotEmpty;
        if (!hasCats && !hasDishes) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('В JSON нет массивов categories или dishes'),
            ),
          );
          return;
        }
      }

      setState(() {
        _fileController.text = fileName;
        _parsedPayloadRoot = payloadRoot;
        _payloadController.text = const JsonEncoder.withIndent('  ').convert(payloadRoot);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось прочитать файл.'))),
      );
    }
  }

  dynamic _parseJsonPayload(String content) {
    final parsed = jsonDecode(content);
    if (parsed is List) {
      return parsed
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
    }
    if (parsed is Map) {
      final m = parsed.map((key, value) => MapEntry(key.toString(), value));
      if (m['data'] is List) {
        return (m['data']! as List)
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .toList();
      }
      if (m.containsKey('categories') || m.containsKey('dishes')) {
        return Map<String, dynamic>.from(m);
      }
    }
    throw const FormatException(
      'JSON: ожидается массив объектов или объект { "categories": [], "dishes": [] }',
    );
  }

  List<Map<String, dynamic>> _parseCsvPayload(String content) {
    final lines = content
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.length < 2) return <Map<String, dynamic>>[];

    final delimiter = _detectCsvDelimiter(lines.first);
    final headers =
        _splitCsvLine(lines.first, delimiter).map((h) => h.trim()).toList();
    if (headers.isEmpty || headers.any((h) => h.isEmpty)) {
      throw const FormatException('Некорректный заголовок CSV');
    }

    final rows = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      final values = _splitCsvLine(line, delimiter);
      final row = <String, dynamic>{};
      for (var i = 0; i < headers.length; i++) {
        final rawValue = i < values.length ? values[i].trim() : '';
        row[headers[i]] = _castCsvValue(rawValue);
      }
      rows.add(row);
    }
    return rows;
  }

  String _detectCsvDelimiter(String headerLine) {
    final semis = ';'.allMatches(headerLine).length;
    final commas = ','.allMatches(headerLine).length;
    if (semis > commas) return ';';
    return ',';
  }

  List<String> _splitCsvLine(String line, String delimiter) {
    if (delimiter.length != 1) {
      throw FormatException('Неподдерживаемый разделитель CSV: $delimiter');
    }
    final delim = delimiter.codeUnitAt(0);
    final result = <String>[];
    final buffer = StringBuffer();
    var insideQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        final isEscapedQuote = insideQuotes && i + 1 < line.length && line[i + 1] == '"';
        if (isEscapedQuote) {
          buffer.write('"');
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (line.codeUnitAt(i) == delim && !insideQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  dynamic _castCsvValue(String value) {
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
    final intValue = int.tryParse(value);
    if (intValue != null) return intValue;
    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue;
    return value;
  }

  Future<void> _submit() async {
    if (_fileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите файл импорта')),
      );
      return;
    }
    if (_payloadController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте JSON-массив данных для импорта')),
      );
      return;
    }

    late final dynamic payloadRoot;
    try {
      payloadRoot = _parsedPayloadRoot ??
          _parseJsonPayload(_payloadController.text.trim());
      if (payloadRoot is List && payloadRoot.isEmpty) {
        throw const FormatException('Массив данных пустой');
      }
      if (payloadRoot is Map) {
        final cats = payloadRoot['categories'];
        final dishes = payloadRoot['dishes'];
        final hasCats = cats is List && cats.isNotEmpty;
        final hasDishes = dishes is List && dishes.isNotEmpty;
        if (!hasCats && !hasDishes) {
          throw const FormatException('Нужны непустые categories и/или dishes');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Некорректные данные для импорта.'))),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await AppDi.adminRepository.createImport({
        'import_type': _mapImportType(_importType),
        'file_name': _fileController.text.trim(),
        'payload': payloadRoot,
        'comment': _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      });
      if (!mounted) return;
      final ic = result['inserted_categories_count'];
      final id = result['inserted_dishes_count'];
      final sk = result['skipped_count'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [
              'Импорт выполнен',
              if (ic is int) 'Категорий: $ic',
              if (id is int) 'Блюд: $id',
              if (sk is int && sk > 0) 'Пропущено строк: $sk',
            ].join('. '),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          msg = data['error'].toString();
        } else {
          msg = e.message ?? e.toString();
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка импорта: $msg')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Импорт данных'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: _importType,
              decoration: const InputDecoration(
                labelText: 'Тип импортируемых данных',
              ),
              items: const [
                DropdownMenuItem(value: 'Импорт меню', child: Text('Импорт меню')),
                DropdownMenuItem(value: 'Импорт категорий', child: Text('Импорт категорий')),
                DropdownMenuItem(value: 'Импорт блюд', child: Text('Импорт блюд')),
              ],
              onChanged: (value) {
                setState(() {
                  _importType = value ?? 'Импорт меню';
                });
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _fileController,
              hintText: 'Название файла (например, menu_import.json)',
              readOnly: true,
              onTap: _pickAndParseFile,
              suffixIcon: const Icon(Icons.attach_file_rounded),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _payloadController,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Данные (JSON)',
                hintText:
                    '[{"title":"Плов","category_id":1,"price":450,"weight":250,"description":"","ingredients":""}] или {"categories":[],"dishes":[]}',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _commentController,
              hintText: 'Комментарий',
              maxLength: 200,
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: _isSubmitting ? 'Выполняется...' : 'Запустить импорт',
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}