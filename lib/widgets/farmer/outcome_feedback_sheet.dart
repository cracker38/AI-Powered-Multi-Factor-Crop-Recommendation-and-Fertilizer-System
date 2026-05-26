import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../services/api_service.dart';

class OutcomeFeedbackSheet extends StatefulWidget {
  const OutcomeFeedbackSheet({
    super.key,
    required this.api,
    required this.predictionId,
    required this.recommendedCrop,
    this.existingRating,
  });

  final ApiService api;
  final String predictionId;
  final String recommendedCrop;
  final int? existingRating;

  @override
  State<OutcomeFeedbackSheet> createState() => _OutcomeFeedbackSheetState();
}

class _OutcomeFeedbackSheetState extends State<OutcomeFeedbackSheet> {
  final _cropController = TextEditingController();
  final _notesController = TextEditingController();
  int _rating = 4;
  bool _followedFertilizer = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cropController.text = widget.recommendedCrop;
    if (widget.existingRating != null) _rating = widget.existingRating!;
  }

  @override
  void dispose() {
    _cropController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.existingRating != null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.submitOutcomeFeedback(
        predictionId: widget.predictionId,
        yieldRating: _rating,
        cropGrown: _cropController.text.trim(),
        followedFertilizer: _followedFertilizer,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = widget.existingRating != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              readOnly ? 'Your harvest feedback' : 'Rate this recommendation',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              readOnly
                  ? 'Thank you — your feedback helps improve future recommendations.'
                  : 'How did this crop and fertilizer plan work on your farm?',
              style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            const Text('Harvest success (1–5)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: readOnly ? null : () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFF9A825),
                    size: 36,
                  ),
                );
              }),
            ),
            TextField(
              controller: _cropController,
              readOnly: readOnly,
              decoration: const InputDecoration(
                labelText: 'Crop actually grown',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('I followed the fertilizer plan'),
              value: _followedFertilizer,
              onChanged: readOnly ? null : (v) => setState(() => _followedFertilizer = v),
            ),
            TextField(
              controller: _notesController,
              readOnly: readOnly,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Yield, challenges, soil changes…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (!readOnly)
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit feedback', style: TextStyle(fontWeight: FontWeight.w700)),
              )
            else
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showOutcomeFeedbackSheet(
  BuildContext context, {
  required ApiService api,
  required String predictionId,
  required String recommendedCrop,
  int? existingRating,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => OutcomeFeedbackSheet(
      api: api,
      predictionId: predictionId,
      recommendedCrop: recommendedCrop,
      existingRating: existingRating,
    ),
  );
}
