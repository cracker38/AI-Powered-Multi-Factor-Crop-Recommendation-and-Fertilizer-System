import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/agriculture_options.dart';
import '../../core/app_colors.dart';
import '../../core/farmer_theme.dart';
import '../../models/farm_input.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/auth/auth_form_card.dart';
import '../../widgets/farmer/farmer_input_field.dart';
import '../../widgets/farmer/farmer_page_header.dart';
import '../../widgets/farmer/farmer_section_title.dart';
import 'recommendation_result_screen.dart';

class RecommendationInputScreen extends StatefulWidget {
  const RecommendationInputScreen({
    super.key,
    required this.api,
    this.profile,
    this.onEvaluationComplete,
  });

  final ApiService api;
  final UserProfile? profile;
  final VoidCallback? onEvaluationComplete;

  @override
  State<RecommendationInputScreen> createState() => _RecommendationInputScreenState();
}

class _RecommendationInputScreenState extends State<RecommendationInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _n = TextEditingController(text: '90');
  final _p = TextEditingController(text: '42');
  final _k = TextEditingController(text: '43');
  final _ph = TextEditingController(text: '6.5');
  final _moisture = TextEditingController(text: '55');
  final _temp = TextEditingController(text: '24');
  final _rain = TextEditingController(text: '200');
  final _hum = TextEditingController(text: '80');
  String _soilType = 'loam';
  String _season = 'season_a';
  bool _busy = false;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final input = FarmInput(
        nitrogen: _parse(_n.text, min: 0, max: 500)!,
        phosphorus: _parse(_p.text, min: 0, max: 500)!,
        potassium: _parse(_k.text, min: 0, max: 500)!,
        soilMoisture: _parse(_moisture.text, min: 0, max: 100)!,
        temperatureC: _parse(_temp.text, min: -10, max: 55)!,
        humidityPct: _parse(_hum.text, min: 0, max: 100)!,
        soilPh: _parse(_ph.text, min: 0, max: 14)!,
        rainfallMm: _parse(_rain.text, min: 0, max: 2000)!,
        soilType: _soilType,
        season: _season,
        district: widget.profile?.district,
      );
      final result = await widget.api.evaluate(input);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirestoreService().savePrediction(
          userUid: uid,
          input: input,
          result: result,
          predictionId: result.predictionId,
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RecommendationResultScreen(prediction: result, api: widget.api),
        ),
      );
      widget.onEvaluationComplete?.call();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items.map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FarmerTheme.surface,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: FarmerPageHeader(
              title: 'Multi-factor analysis',
              subtitle:
                  'Soil nutrients, climate, soil type, season, and location — AI recommends crops and precision fertilizers.',
              icon: Icons.psychology_rounded,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverToBoxAdapter(
              child: AuthFormCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FarmerSectionTitle(title: 'Field context'),
                      _dropdown(
                        label: 'Soil type',
                        value: _soilType,
                        items: AgricultureOptions.soilTypes,
                        icon: Icons.terrain_rounded,
                        onChanged: (v) => setState(() => _soilType = v ?? 'loam'),
                      ),
                      const SizedBox(height: 12),
                      _dropdown(
                        label: 'Growing season',
                        value: _season,
                        items: AgricultureOptions.seasons,
                        icon: Icons.calendar_month_rounded,
                        onChanged: (v) => setState(() => _season = v ?? 'season_a'),
                      ),
                      if (widget.profile?.district != null && widget.profile!.district!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.place_rounded, color: AppColors.primary),
                          title: const Text('Location', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(widget.profile!.district!),
                        ),
                      ],
                      const SizedBox(height: 20),
                      const FarmerSectionTitle(title: 'Soil nutrients & pH'),
                      FarmerInputField(
                        label: 'Nitrogen (N) kg/ha',
                        controller: _n,
                        icon: Icons.science_outlined,
                        min: 0,
                        max: 500,
                        hint: 'e.g. 90',
                      ),
                      const SizedBox(height: 12),
                      FarmerInputField(
                        label: 'Phosphorus (P) kg/ha',
                        controller: _p,
                        icon: Icons.water_drop_outlined,
                        min: 0,
                        max: 500,
                      ),
                      const SizedBox(height: 12),
                      FarmerInputField(
                        label: 'Potassium (K) kg/ha',
                        controller: _k,
                        icon: Icons.grain_rounded,
                        min: 0,
                        max: 500,
                      ),
                      const SizedBox(height: 12),
                      FarmerInputField(
                        label: 'Soil pH',
                        controller: _ph,
                        icon: Icons.opacity_rounded,
                        min: 0,
                        max: 14,
                      ),
                      const SizedBox(height: 12),
                      FarmerInputField(
                        label: 'Soil moisture %',
                        controller: _moisture,
                        icon: Icons.water_rounded,
                        min: 0,
                        max: 100,
                      ),
                      const SizedBox(height: 20),
                      const FarmerSectionTitle(title: 'Climate & rainfall'),
                      FarmerInputField(
                        label: 'Temperature °C',
                        controller: _temp,
                        icon: Icons.thermostat_rounded,
                        min: -10,
                        max: 55,
                      ),
                      const SizedBox(height: 12),
                      FarmerInputField(
                        label: 'Rainfall (mm)',
                        controller: _rain,
                        icon: Icons.cloud_outlined,
                        min: 0,
                        max: 2000,
                      ),
                      const SizedBox(height: 12),
                      FarmerInputField(
                        label: 'Humidity %',
                        controller: _hum,
                        icon: Icons.air_rounded,
                        min: 0,
                        max: 100,
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_awesome_rounded),
                                  SizedBox(width: 10),
                                  Text(
                                    'Get crop & fertilizer plan',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
