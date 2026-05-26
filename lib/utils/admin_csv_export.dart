import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/admin_prediction.dart';
import '../models/admin_user.dart';

abstract final class AdminCsvExport {
  static String farmers(List<AdminUser> users) {
    final buf = StringBuffer('email,display_name,phone,district,disabled,predictions,created_at\n');
    for (final u in users.where((u) => u.isFarmer)) {
      final created = u.createdAt != null ? DateFormat('yyyy-MM-dd').format(u.createdAt!) : '';
      buf.writeln(
        '${_esc(u.email)},${_esc(u.displayName ?? '')},${_esc(u.phone ?? '')},${_esc(u.district ?? '')},'
        '${u.disabled},${u.predictionCount},$created',
      );
    }
    return buf.toString();
  }

  static String predictions(List<AdminPrediction> items) {
    final buf = StringBuffer(
      'id,farmer_email,farmer_name,top_crop,confidence_pct,model_version,created_at\n',
    );
    for (final p in items) {
      final when = p.createdAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(p.createdAt!) : '';
      buf.writeln(
        '${_esc(p.id)},${_esc(p.farmerEmail ?? '')},${_esc(p.farmerName ?? '')},'
        '${_esc(p.topCrop)},${(p.topConfidence * 100).toStringAsFixed(1)},'
        '${_esc(p.modelVersion)},$when',
      );
    }
    return buf.toString();
  }

  static String _esc(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<void> copyToClipboard(BuildContext context, String csv, {required String label}) async {
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label copied to clipboard — paste into Excel or Sheets')),
      );
    }
  }
}
