import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/services/reverse_geocode_service.dart';

class AddressMapPickerResult {
  const AddressMapPickerResult({
    required this.latitude,
    required this.longitude,
    this.suggestedAddress,
  });

  final double latitude;
  final double longitude;
  final String? suggestedAddress;
}

class AddressMapPickerPage extends StatefulWidget {
  const AddressMapPickerPage({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  final double? initialLatitude;
  final double? initialLongitude;

  @override
  State<AddressMapPickerPage> createState() => _AddressMapPickerPageState();
}

class _AddressMapPickerPageState extends State<AddressMapPickerPage> {
  static final LatLng _defaultCenter = LatLng(43.9053, 42.7144);

  final MapController _mapController = MapController();
  late LatLng _marker;
  String? _resolvedAddress;
  bool _resolving = false;
  Timer? _geocodeDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _marker = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      _marker = _defaultCenter;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.move(_marker, 15);
      _scheduleReverseGeocode(_marker);
    });
  }

  @override
  void dispose() {
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  void _scheduleReverseGeocode(LatLng point) {
    _geocodeDebounce?.cancel();
    setState(() {
      _resolving = true;
    });
    _geocodeDebounce = Timer(const Duration(milliseconds: 650), () async {
      final text = await ReverseGeocodeService.reverse(
        point.latitude,
        point.longitude,
      );
      if (!mounted) return;
      setState(() {
        _resolvedAddress = text;
        _resolving = false;
      });
    });
  }

  Future<void> _useMyLocation() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужен доступ к геолокации')),
      );
      return;
    }

    final service = await Geolocator.isLocationServiceEnabled();
    if (!service) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Включите службы геолокации')),
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      final p = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _marker = p);
      _mapController.move(p, 16);
      _scheduleReverseGeocode(p);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось получить координаты')),
      );
    }
  }

  void _confirm() {
    Navigator.of(context).pop(
      AddressMapPickerResult(
        latitude: _marker.latitude,
        longitude: _marker.longitude,
        suggestedAddress: _resolvedAddress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Точка на карте'),
        actions: [
          TextButton(
            onPressed: _resolving ? null : _confirm,
            child: const Text('Готово'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Нажмите на карту, чтобы поставить метку доставки. Адрес подтянется автоматически (при наличии сети).',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _useMyLocation,
                  icon: const Icon(Icons.my_location_rounded, size: 20),
                  label: const Text('Моё местоположение'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _marker,
                  initialZoom: 15,
                  minZoom: 3,
                  maxZoom: 19,
                  onTap: (_, point) {
                    setState(() => _marker = point);
                    _scheduleReverseGeocode(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.kavkaz.restaurant',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _marker,
                        width: 44,
                        height: 52,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.place_rounded,
                          size: 52,
                          color: AppColors.primary,
                          shadows: const [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: AppColors.surface,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_marker.latitude.toStringAsFixed(5)}, ${_marker.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (_resolving)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    if (_resolvedAddress != null &&
                        _resolvedAddress!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _resolvedAddress!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _resolving ? null : _confirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Использовать эту точку'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
