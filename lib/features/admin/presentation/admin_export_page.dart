import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/di.dart';
import '../../../core/utils/humanize_error.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/primary_button.dart';

class AdminExportPage extends StatefulWidget {
  const AdminExportPage({super.key});

  @override
  State<AdminExportPage> createState() => _AdminExportPageState();
}

class _AdminExportPageState extends State<AdminExportPage> {
  static const MethodChannel _filesChannel =
      MethodChannel('kavkaz_restourant/files');

  List<Map<String, dynamic>> _exportTypes = [];
  String? _selectedTypeId;
  bool _loadingExportTypes = true;
  bool _refreshingExportTypes = false;
  String _format = 'csv';
  final _periodController = TextEditingController();
  bool _isSubmitting = false;
  bool _isDownloading = false;
  String? _lastFileName;
  String? _lastFileUrl;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );

  static List<Map<String, dynamic>> _fallbackExportTypes() => [
        {
          'code': 'orders',
          'title': 'Экспорт заказов',
          'sort_order': 10,
          'requires_date_range': true,
          'json_only': false,
        },
        {
          'code': 'users',
          'title': 'Экспорт пользователей',
          'sort_order': 20,
          'requires_date_range': true,
          'json_only': false,
        },
        {
          'code': 'categories',
          'title': 'Экспорт категорий (импорт)',
          'sort_order': 30,
          'requires_date_range': false,
          'json_only': false,
        },
        {
          'code': 'dishes',
          'title': 'Экспорт меню',
          'sort_order': 40,
          'requires_date_range': false,
          'json_only': false,
        },
        {
          'code': 'menu',
          'title': 'Экспорт меню - категории и блюда (JSON)',
          'sort_order': 50,
          'requires_date_range': false,
          'json_only': true,
        },
      ];

  String _typeValue(Map<String, dynamic> row) {
    final id = row['id_export_type']?.toString().trim();
    if (id != null && id.isNotEmpty) return id;
    final code = row['code']?.toString().trim() ?? '';
    final title = row['title']?.toString().trim() ?? '';
    return '$code|$title';
  }

  List<Map<String, dynamic>> _sanitizeExportTypes(List<Map<String, dynamic>> rows) {
    final unique = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final rawCode = row['code']?.toString().trim() ?? '';
      if (rawCode.isEmpty) continue;
      final key = _typeValue(row);
      unique.putIfAbsent(key, () => Map<String, dynamic>.from(row));
    }
    return unique.values.toList();
  }

  Map<String, dynamic>? _selectedRow() {
    final selectedId = _selectedTypeId;
    if (selectedId == null) return null;
    for (final row in _exportTypes) {
      if (_typeValue(row) == selectedId) return row;
    }
    return null;
  }

  bool _boolField(Map<String, dynamic>? row, String key) {
    if (row == null) return false;
    final v = row[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().toLowerCase();
    return s == 'true' || s == 't' || s == '1';
  }

  @override
  void initState() {
    super.initState();
    _syncPeriodController();
    _loadExportTypes();
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  Future<void> _loadExportTypes({bool silent = false}) async {
    final prevTypeId = _selectedTypeId;
    if (silent) {
      setState(() => _refreshingExportTypes = true);
    } else {
      setState(() => _loadingExportTypes = true);
    }
    try {
      final rows = await AppDi.adminRepository.getExportTypes();
      rows.sort((a, b) {
        final sa = (a['sort_order'] as num?)?.toInt() ?? 0;
        final sb = (b['sort_order'] as num?)?.toInt() ?? 0;
        return sa.compareTo(sb);
      });
      final normalizedRows = _sanitizeExportTypes(rows);
      if (!mounted) return;
      setState(() {
        _exportTypes = normalizedRows.isNotEmpty
            ? normalizedRows
            : _sanitizeExportTypes(_fallbackExportTypes());
        if (prevTypeId != null &&
            _exportTypes.any((e) => _typeValue(e) == prevTypeId)) {
          _selectedTypeId = prevTypeId;
        } else {
          _selectedTypeId = _typeValue(_exportTypes.first);
        }
        _applyJsonOnlyFromSelection();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _exportTypes = _sanitizeExportTypes(_fallbackExportTypes());
        if (prevTypeId != null &&
            _exportTypes.any((e) => _typeValue(e) == prevTypeId)) {
          _selectedTypeId = prevTypeId;
        } else {
          _selectedTypeId = _typeValue(_exportTypes.first);
        }
        _applyJsonOnlyFromSelection();
      });
      final msg = e is DioException
          ? (e.response?.data is Map && (e.response!.data as Map)['error'] != null
              ? (e.response!.data as Map)['error'].toString()
              : (e.message ?? e.toString()))
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось загрузить типы экспорта из базы. Используется список по умолчанию. ${humanizeError(msg)}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingExportTypes = false;
          _refreshingExportTypes = false;
        });
      }
    }
  }

  void _applyJsonOnlyFromSelection() {
    if (_boolField(_selectedRow(), 'json_only')) {
      _format = 'json';
    }
  }

  void _syncPeriodController() {
    final formatter = DateFormat('dd.MM.yyyy');
    _periodController.text =
        '${formatter.format(_dateRange.start)} - ${formatter.format(_dateRange.end)}';
  }

  Future<void> _pickPeriod() async {
    final selectedRange = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Выберите период',
    );
    if (selectedRange == null) return;
    setState(() {
      _dateRange = selectedRange;
      _syncPeriodController();
    });
  }

  Future<void> _submit() async {
    final selected = _selectedRow();
    final typeKey = selected?['code']?.toString();
    if (typeKey == null || typeKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите тип экспорта')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      var format = _format;
      if (_boolField(_selectedRow(), 'json_only') && format != 'json') {
        format = 'json';
        if (mounted) setState(() => _format = 'json');
      }
      final exportResult = await AppDi.adminRepository.createExport({
        'export_type': typeKey,
        'date_from': _dateRange.start.toIso8601String(),
        'date_to': _dateRange.end.toIso8601String(),
        'format': format,
      });
      if (!mounted) return;
      final total = exportResult['total'];
      final filePath = exportResult['file_path']?.toString();
      final fileUrl = exportResult['file_url']?.toString();
      setState(() {
        _lastFileName = exportResult['file_name']?.toString();
        _lastFileUrl = fileUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            [
              total is int
                  ? 'Экспорт сформирован: $total записей'
                  : 'Экспорт сформирован',
              if (filePath != null && filePath.isNotEmpty) 'Файл: $filePath',
              if (fileUrl != null && fileUrl.isNotEmpty) 'URL: $fileUrl',
            ].join('\n'),
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
        SnackBar(content: Text(humanizeError(msg, fallback: 'Не удалось сформировать экспорт.'))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _downloadToDevice() async {
    final fileUrl = _lastFileUrl;
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала сформируйте экспорт')),
      );
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final baseUrl = AppDi.apiService.dio.options.baseUrl;
      final resolvedUrl = Uri.parse(baseUrl).resolve(fileUrl).toString();
      final ext = (_lastFileName != null && _lastFileName!.contains('.'))
          ? _lastFileName!.split('.').last.toLowerCase()
          : _format;
      final fallbackName = 'export_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final fileName = (_lastFileName == null || _lastFileName!.isEmpty)
          ? fallbackName
          : _lastFileName!;
      String outputPath;

      if (Platform.isAndroid) {
        final tempDir = await getTemporaryDirectory();
        final tempPath =
            '${tempDir.path}${Platform.pathSeparator}export_dl_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await AppDi.apiService.dio.download(
          resolvedUrl,
          tempPath,
          options: Options(
            receiveTimeout: const Duration(minutes: 3),
            sendTimeout: const Duration(minutes: 3),
          ),
        );
        final tmp = File(tempPath);
        if (!await tmp.exists() || await tmp.length() == 0) {
          throw Exception('Пустой или не загруженный файл');
        }
        try {
          final savedUri = await _filesChannel.invokeMethod<String>(
            'saveToDownloads',
            {
              'fileName': fileName,
              'mimeType': ext == 'json' ? 'application/json' : 'text/csv',
              'sourceFilePath': tempPath,
            },
          );
          if (savedUri == null || savedUri.isEmpty) {
            throw Exception('Не удалось сохранить файл в системное хранилище');
          }
          outputPath = savedUri;
        } finally {
          try {
            if (await tmp.exists()) await tmp.delete();
          } catch (_) {}
        }
      } else {
        final outputDir = await _resolvePreferredSaveDirectory();
        await outputDir.create(recursive: true);
        outputPath = '${outputDir.path}${Platform.pathSeparator}$fileName';
        await AppDi.apiService.dio.download(
          resolvedUrl,
          outputPath,
          deleteOnError: true,
        );
      }

      if (!mounted) return;
      final isAndroidMediaStore = Platform.isAndroid;
      final isDownloadsDir = outputPath.toLowerCase().contains('download');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAndroidMediaStore
                ? 'Файл сохранен в Download (MediaStore): $outputPath'
                : (isDownloadsDir
                      ? 'Файл сохранен в Download: $outputPath'
                      : 'Download недоступна, файл сохранен в папку приложения: $outputPath'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(humanizeError(e, fallback: 'Не удалось скачать файл экспорта.'))),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<Directory> _resolvePreferredSaveDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) return downloadsDir;
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) return externalDir;
    }
    return getApplicationDocumentsDirectory();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExportTypes) {
      return AppScaffold(
        appBar: AppBar(title: const Text('Экспорт данных')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final selected = _selectedRow();
    final usesPeriod = _boolField(selected, 'requires_date_range');
    final jsonOnly = _boolField(selected, 'json_only');

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Экспорт данных'),
        actions: [
          IconButton(
            tooltip: 'Обновить типы из БД',
            onPressed: _refreshingExportTypes
                ? null
                : () => _loadExportTypes(silent: true),
            icon: _refreshingExportTypes
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _selectedTypeId != null &&
                      _exportTypes.any((e) => _typeValue(e) == _selectedTypeId)
                  ? _selectedTypeId
                  : _typeValue(_exportTypes.first),
              decoration: const InputDecoration(
                labelText: 'Тип данных',
              ),
              items: _exportTypes
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: _typeValue(e),
                      child: Text(
                        e['title']?.toString() ?? e['code']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTypeId = value;
                  _applyJsonOnlyFromSelection();
                });
              },
            ),
            const SizedBox(height: 14),
            if (usesPeriod) ...[
              TextField(
                controller: _periodController,
                readOnly: true,
                onTap: _pickPeriod,
                decoration: const InputDecoration(
                  labelText: 'Период дат',
                  suffixIcon: Icon(Icons.date_range_rounded),
                ),
              ),
              const SizedBox(height: 14),
            ] else ...[
              Text(
                'Период не используется для этого типа выгрузки.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
            ],
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: jsonOnly
                  ? 'json'
                  : (_format == 'json' || _format == 'csv' ? _format : 'csv'),
              decoration: const InputDecoration(
                labelText: 'Формат файла',
              ),
              items: jsonOnly
                  ? const [
                      DropdownMenuItem(value: 'json', child: Text('JSON')),
                    ]
                  : const [
                      DropdownMenuItem(value: 'csv', child: Text('CSV')),
                      DropdownMenuItem(value: 'json', child: Text('JSON')),
                    ],
              onChanged: jsonOnly
                  ? null
                  : (value) {
                      setState(() {
                        _format = value ?? 'csv';
                      });
                    },
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              text: _isSubmitting ? 'Выполняется...' : 'Сформировать выгрузку',
              onPressed: _isSubmitting ? null : _submit,
            ),
            if (_lastFileUrl != null && _lastFileUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isDownloading ? null : _downloadToDevice,
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  _isDownloading ? 'Скачивание...' : 'Скачать на устройство',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
