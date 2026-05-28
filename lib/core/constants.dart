import 'package:flutter/foundation.dart';

import 'brand.dart';

/// Reserved admin email — registration must reject this address.
const String kAdminEmail = 'uwayiedissa@gmail.com';

const String kAppTitle = Brand.productName;
const String kAppTagline = Brand.tagline;

/// Default API base for login screen (platform-aware).
String get kDefaultApiBase {
  // Use localhost on web so origin matches typical Flutter dev server host.
  if (kIsWeb) return 'http://localhost:8000';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:8000';
    default:
      return 'http://127.0.0.1:8000';
  }
}
