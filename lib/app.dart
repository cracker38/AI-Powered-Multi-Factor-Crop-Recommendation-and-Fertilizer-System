import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'screens/app_entry.dart';

class CropRecommendationApp extends StatelessWidget {
  const CropRecommendationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppTitle,
      theme: buildAppTheme(),
      home: const AppEntry(),
      debugShowCheckedModeBanner: false,
    );
  }
}
