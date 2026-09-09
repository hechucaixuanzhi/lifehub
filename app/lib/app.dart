import 'package:flutter/material.dart';

import 'features/shell/app_shell.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LifeHub',
        theme: AppTheme.light(),
        home: const AppShell(),
        debugShowCheckedModeBanner: false,
      );
}
