import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import 'l10n/strings.dart';
import 'logic/location.dart';
import 'state/app_scope.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/info_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/setup_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locale = PlatformDispatcher.instance.locale;
  final state = await AppState.load(
    deviceLang: locale.languageCode == 'ja' ? Lang.ja : Lang.en,
    guessedLocation: guessFromTimeZone(DateTime.now().timeZoneName, localeCountry: locale.countryCode),
  );
  runApp(MoneyPlannerApp(state: state));
}

class MoneyPlannerApp extends StatelessWidget {
  const MoneyPlannerApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: state.s.t('app.title'),
        debugShowCheckedModeBanner: false,
        theme: buildTheme(state.display),
        locale: Locale(state.lang.name),
        // Apply the chosen text size on top of the phone's own accessibility setting.
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final system = mq.textScaler.scale(1);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear((system * state.textSize.scale).clamp(1.0, 2.4))),
            child: child!,
          );
        },
        home: state.setupDone ? const AppShell() : const SetupScreen(),
      ),
    ),
  );
}

/// The three main tabs, always labelled.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final notice = app.notice;
    if (notice != null) {
      app.clearNotice();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice), duration: const Duration(seconds: 8)));
      });
    }
    return Scaffold(
      body: IndexedStack(index: _tab, children: const [HomeScreen(), InfoScreen(), SettingsScreen()]),
      // Tab labels may grow a little with the text size, but not so much that they get cut off.
      bottomNavigationBar: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: s.t('nav.budget'),
            ),
            NavigationDestination(icon: const Icon(Icons.person_outline), selectedIcon: const Icon(Icons.person), label: s.t('nav.info')),
            NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: s.t('nav.settings')),
          ],
        ),
      ),
    );
  }
}
