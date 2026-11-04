import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import 'steps.dart';
import 'widgets.dart';

/// First-run questions, one per screen.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _step = 0;
  final _scroll = ScrollController();
  static const _questions = 4;

  void _go(int to) {
    setState(() => _step = to);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final tt = Theme.of(context).textTheme;
    final last = _step == _questions;
    final body = switch (_step) {
      0 => const _Welcome(),
      1 => const LocationStep(autoDetect: true),
      2 => const IncomeStep(),
      3 => const HouseholdStep(),
      _ => const BillsStep(),
    };

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          if (_step > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.t('common.step', {'n': _step, 'total': _questions}), style: tt.titleMedium),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(value: _step / _questions, minHeight: 12),
                ),
              ]),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(20, 24, 20, 24), children: [body]),
              ),
            ),
          ),
          _BottomBar(
            onBack: _step > 0 ? () => _go(_step - 1) : null,
            nextLabel: _step == 0 ? s.t('welcome.start') : last ? s.t('bills.finish') : s.t('common.next'),
            onNext: last ? app.finishSetup : () => _go(_step + 1),
          ),
        ]),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onBack, required this.nextLabel, required this.onNext});
  final VoidCallback? onBack;
  final String nextLabel;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: cs.surface, border: Border(top: BorderSide(color: cs.outlineVariant, width: 1.5))),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Row(children: [
            if (onBack != null) ...[
              Expanded(flex: 2, child: BigButton(icon: Icons.arrow_back, label: s.t('common.back'), onPressed: onBack, outlined: true)),
              const SizedBox(width: 12),
            ],
            Expanded(flex: 3, child: BigButton(label: nextLabel, onPressed: onNext, icon: Icons.arrow_forward)),
          ]),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Center(
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(28)),
          child: Icon(Icons.account_balance_wallet_rounded, size: 64, color: cs.onPrimary),
        ),
      ),
      const SizedBox(height: 24),
      Text(s.t('app.title'), textAlign: TextAlign.center, style: tt.titleLarge?.copyWith(color: cs.primary)),
      const SizedBox(height: 8),
      Semantics(header: true, child: Text(s.t('welcome.title'), textAlign: TextAlign.center, style: tt.headlineMedium)),
      const SizedBox(height: 16),
      Text(s.t('welcome.body'), textAlign: TextAlign.center, style: tt.bodyLarge),
      const SizedBox(height: 36),
      Text(s.t('welcome.language'), style: tt.titleMedium),
      const SizedBox(height: 8),
      const LanguagePicker(),
      const SizedBox(height: 28),
      Text(s.t('welcome.textSize'), style: tt.titleMedium),
      const SizedBox(height: 8),
      const TextSizePicker(),
    ]);
  }
}

/// Three big buttons showing "Aa" at each size.
class TextSizePicker extends StatelessWidget {
  const TextSizePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      for (final (i, size) in TextSize.values.indexed) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            selected: app.textSize == size,
            button: true,
            label: s.t('settings.size.${size.name}'),
            child: Material(
              color: app.textSize == size ? cs.primaryContainer : Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: app.textSize == size ? cs.primary : cs.outlineVariant, width: app.textSize == size ? 3 : 1.5),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => app.setTextSize(size),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: ExcludeSemantics(
                    child: Column(children: [
                      // Show the sample at a fixed size so the three buttons stay comparable.
                      MediaQuery.withNoTextScaling(child: Text('Aa', style: TextStyle(fontSize: 22 * size.scale, fontWeight: FontWeight.w700))),
                      const SizedBox(height: 4),
                      MediaQuery.withNoTextScaling(
                        child: Text(s.t('settings.size.${size.name}'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Japanese / English, one big button each.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Column(children: [
      ChoiceTile(title: '日本語', selected: app.lang == Lang.ja, onTap: () => app.setLang(Lang.ja)),
      const SizedBox(height: 10),
      ChoiceTile(title: 'English', selected: app.lang == Lang.en, onTap: () => app.setLang(Lang.en)),
    ]);
  }
}
