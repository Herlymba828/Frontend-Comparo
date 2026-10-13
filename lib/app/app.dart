import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class ComparateurPrixApp extends StatelessWidget {
  const ComparateurPrixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Comparateur Prix',
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
