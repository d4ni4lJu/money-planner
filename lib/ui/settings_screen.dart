import 'package:flutter/material.dart';

import '../logic/models.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import 'setup_screen.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final tt = Theme.of(context).textTheme;
    Widget gap() => const SizedBox(height: 10);

    return Scaffold(
      appBar: AppBar(title: Text(s.t('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionTitle(s.t('settings.textSize')),
                const TextSizePicker(),
                SectionTitle(s.t('settings.display')),
                for (final d in Display.values) ...[
                  ChoiceTile(
                    title: s.t('settings.display.${d.name}'),
                    icon: switch (d) { Display.light => Icons.light_mode, Display.dark => Icons.dark_mode, Display.contrast => Icons.contrast },
                    selected: app.display == d,
                    onTap: () => app.setDisplay(d),
                  ),
                  gap(),
                ],
                SectionTitle(s.t('settings.language')),
                const LanguagePicker(),
                SectionTitle(s.t('settings.method')),
                for (final m in BudgetMethod.values) ...[
                  ChoiceTile(
                    title: s.t('method.${m.name}'),
                    subtitle: s.t('method.${m.name}Hint'),
                    selected: app.inputs.method == m,
                    onTap: () => app.update((i) => i.copyWith(method: m)),
                  ),
                  gap(),
                ],
                SectionTitle(s.t('settings.about')),
                Text(s.t('home.disclaimer', {'year': app.country.data.dataYear}), style: tt.bodyLarge),
                const SizedBox(height: 10),
                Text(s.t('settings.sources'), style: tt.titleMedium),
                for (final src in app.country.data.sources) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $src', style: tt.bodyMedium)),
                const SizedBox(height: 32),
                BigButton(
                  icon: Icons.restart_alt,
                  label: s.t('settings.startOver'),
                  outlined: true,
                  onPressed: () async {
                    if (await confirm(context, s.t('settings.startOverConfirm'), yes: s.t('settings.startOver'))) app.startOver();
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
