import 'package:flutter/material.dart';

import '../../core/agriculture_options.dart';
import '../../core/app_colors.dart';
import '../../models/farmer_field_data.dart';
import '../../models/live_climate.dart';
import '../../services/api_service.dart';
import '../farmer/farmer_input_field.dart';
import '../farmer/live_climate_banner.dart';
import '../farmer/farmer_section_title.dart';

class FarmerFieldDataForm extends StatefulWidget {
  const FarmerFieldDataForm({
    super.key,
    required this.onSubmit,
    this.initial,
    this.busy = false,
    this.submitLabel = 'Submit field data',
    this.api,
    this.district,
  });

  final Future<void> Function(FarmerFieldData data) onSubmit;
  final FarmerFieldData? initial;
  final bool busy;
  final String submitLabel;
  final ApiService? api;
  final String? district;

  @override
  State<FarmerFieldDataForm> createState() => FarmerFieldDataFormState();
}

class FarmerFieldDataFormState extends State<FarmerFieldDataForm> {
  final _formKey = GlobalKey<FormState>();
  late final _n = TextEditingController(text: _s(widget.initial?.nitrogen, 90));
  late final _p = TextEditingController(text: _s(widget.initial?.phosphorus, 42));
  late final _k = TextEditingController(text: _s(widget.initial?.potassium, 43));
  late final _ph = TextEditingController(text: _s(widget.initial?.soilPh, 6.5));
  late final _moisture = TextEditingController(text: _s(widget.initial?.soilMoisture, 55));
  late final _temp = TextEditingController(text: _s(widget.initial?.temperatureC, 24));
  late final _rain = TextEditingController(text: _s(widget.initial?.rainfallMm, 200));
  late final _hum = TextEditingController(text: _s(widget.initial?.humidityPct, 80));
  late String _soilType = widget.initial?.soilType ?? 'loam';
  bool _climateLoading = false;
  LiveClimate? _liveClimate;

  static String _s(double? v, double fallback) => (v ?? fallback).toString();

  @override
  void initState() {
    super.initState();
    _loadLiveClimate();
  }

  Future<void> _loadLiveClimate() async {
    final api = widget.api;
    final district = widget.district;
    if (api == null || district == null || district.isEmpty) return;
    setState(() => _climateLoading = true);
    try {
      final climate = await api.fetchLiveClimate(district: district);
      if (!mounted) return;
      setState(() {
        _liveClimate = climate;
        if (climate.available) {
          if (climate.temperatureC != null) _temp.text = climate.temperatureC!.toStringAsFixed(1);
          if (climate.rainfallMm != null) _rain.text = climate.rainfallMm!.toStringAsFixed(0);
          if (climate.humidityPct != null) _hum.text = climate.humidityPct!.toStringAsFixed(0);
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _liveClimate = LiveClimate(available: false, reason: e.message));
      }
    } finally {
      if (mounted) setState(() => _climateLoading = false);
    }
  }

  bool get _climateAuto => _liveClimate?.available == true && widget.district != null && widget.district!.isNotEmpty;

  @override
  void dispose() {
    _n.dispose();
    _p.dispose();
    _k.dispose();
    _ph.dispose();
    _moisture.dispose();
    _temp.dispose();
    _rain.dispose();
    _hum.dispose();
    super.dispose();
  }

  double? _parse(String s, {required double min, required double max}) {
    final v = double.tryParse(s.replaceAll(',', '.'));
    if (v == null || v < min || v > max) return null;
    return v;
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;
    final data = FarmerFieldData(
      nitrogen: _parse(_n.text, min: 0, max: 500)!,
      phosphorus: _parse(_p.text, min: 0, max: 500)!,
      potassium: _parse(_k.text, min: 0, max: 500)!,
      soilMoisture: _parse(_moisture.text, min: 0, max: 100)!,
      temperatureC: _parse(_temp.text, min: -10, max: 55)!,
      humidityPct: _parse(_hum.text, min: 0, max: 100)!,
      soilPh: _parse(_ph.text, min: 0, max: 14)!,
      rainfallMm: _parse(_rain.text, min: 0, max: 2000)!,
      soilType: _soilType,
    );
    await widget.onSubmit(data);
  }

  /// Apply ESP8266 sensor readings (admin approval or refresh).
  void applyFieldData(FarmerFieldData data) {
    setState(() {
      _n.text = data.nitrogen.toString();
      _p.text = data.phosphorus.toString();
      _k.text = data.potassium.toString();
      _ph.text = data.soilPh.toString();
      _moisture.text = data.soilMoisture.toString();
      if (!_climateAuto) {
        _temp.text = data.temperatureC.toString();
        _hum.text = data.humidityPct.toString();
        _rain.text = data.rainfallMm.toString();
      }
      _soilType = data.soilType;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FarmerSectionTitle(title: 'Soil & climate readings'),
          const SizedBox(height: 8),
          FarmerInputField(
            controller: _n,
            label: 'Nitrogen (N) kg/ha',
            icon: Icons.grass_rounded,
            min: 0,
            max: 500,
          ),
          FarmerInputField(
            controller: _p,
            label: 'Phosphorus (P) kg/ha',
            icon: Icons.water_drop_outlined,
            min: 0,
            max: 500,
          ),
          FarmerInputField(
            controller: _k,
            label: 'Potassium (K) kg/ha',
            icon: Icons.bolt_outlined,
            min: 0,
            max: 500,
          ),
          FarmerInputField(
            controller: _ph,
            label: 'Soil pH',
            icon: Icons.science_outlined,
            min: 0,
            max: 14,
          ),
          FarmerInputField(
            controller: _moisture,
            label: 'Soil moisture %',
            icon: Icons.opacity_outlined,
            min: 0,
            max: 100,
          ),
          const SizedBox(height: 12),
          LiveClimateBanner(
            climate: _liveClimate,
            loading: _climateLoading,
            onRefresh: widget.api != null && widget.district != null ? _loadLiveClimate : null,
          ),
          const SizedBox(height: 12),
          FarmerInputField(
            controller: _rain,
            label: 'Rainfall mm (7-day, live)',
            icon: Icons.water_outlined,
            min: 0,
            max: 2000,
            readOnly: _climateAuto,
          ),
          FarmerInputField(
            controller: _temp,
            label: 'Temperature °C (live)',
            icon: Icons.thermostat_outlined,
            min: -10,
            max: 55,
            readOnly: _climateAuto,
          ),
          FarmerInputField(
            controller: _hum,
            label: 'Humidity % (live)',
            icon: Icons.cloud_outlined,
            min: 0,
            max: 100,
            readOnly: _climateAuto,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _soilType,
            decoration: const InputDecoration(labelText: 'Soil type', border: OutlineInputBorder()),
            items: AgricultureOptions.soilTypes
                .map((entry) => DropdownMenuItem(value: entry.$1, child: Text(entry.$2)))
                .toList(),
            onChanged: widget.busy ? null : (v) => setState(() => _soilType = v ?? 'loam'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: widget.busy ? null : submit,
            icon: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(widget.submitLabel),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
