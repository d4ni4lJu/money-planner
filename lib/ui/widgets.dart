import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../logic/models.dart';
import '../state/app_scope.dart';
import 'theme.dart';

/// A big, full-width button with an icon and words.
class BigButton extends StatelessWidget {
  const BigButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = false, this.tonal = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool outlined, tonal;

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 28), const SizedBox(width: 12)],
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ]);
    final b = outlined
        ? OutlinedButton(onPressed: onPressed, child: child)
        : tonal
            ? FilledButton.tonal(onPressed: onPressed, child: child)
            : FilledButton(onPressed: onPressed, child: child);
    return SizedBox(width: double.infinity, child: b);
  }
}

/// A large tappable card for picking one option (works like a radio button).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.title, this.subtitle, required this.selected, required this.onTap, this.icon, this.trailing});
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? cs.primaryContainer : Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 3 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 30, color: selected ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 14),
                if (icon != null) ...[Icon(icon, size: 30), const SizedBox(width: 12)],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ),
                ?trailing,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Yes / No as two big choice tiles.
class YesNo extends StatelessWidget {
  const YesNo({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).s;
    return Row(children: [
      Expanded(child: ChoiceTile(title: s.t('common.yes'), selected: value, onTap: () => onChanged(true))),
      const SizedBox(width: 12),
      Expanded(child: ChoiceTile(title: s.t('common.no'), selected: !value, onTap: () => onChanged(false))),
    ]);
  }
}

/// A number with big − and + buttons.
class CountStepper extends StatelessWidget {
  const CountStepper({super.key, required this.label, required this.value, required this.min, required this.max, required this.onChanged});
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: tt.titleMedium),
      const SizedBox(height: 8),
      Row(children: [
        _RoundButton(icon: Icons.remove, label: '−', onPressed: value > min ? () => onChanged(value - 1) : null),
        Expanded(child: Text('$value', textAlign: TextAlign.center, style: tt.displaySmall, semanticsLabel: '$label: $value')),
        _RoundButton(icon: Icons.add, label: '+', onPressed: value < max ? () => onChanged(value + 1) : null),
      ]),
    ]);
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: SizedBox(
          width: 72,
          height: 72,
          child: FilledButton.tonal(
            onPressed: onPressed,
            style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: const CircleBorder()),
            child: Icon(icon, size: 34),
          ),
        ),
      );
}

/// Shows numbers with thousands separators while typing ("42,900").
class _ThousandsFormatter extends TextInputFormatter {
  static final _f = NumberFormat('#,##0', 'en_US');
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = _f.format(int.parse(digits.length > 12 ? digits.substring(0, 12) : digits));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

String _fmt(double? v) => v == null ? '' : NumberFormat('#,##0', 'en_US').format(v.round());
double? parseMoney(String s) {
  final d = s.replaceAll(RegExp(r'[^0-9]'), '');
  return d.isEmpty ? null : double.parse(d);
}

/// A large money entry box with − / + buttons. `value == null` means empty.
class MoneyField extends StatefulWidget {
  const MoneyField({super.key, required this.label, required this.value, required this.onChanged, this.step, this.hint, this.helper, this.autofocus = false});
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  final double? step;
  final String? hint, helper;
  final bool autofocus;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final _c = TextEditingController(text: _fmt(widget.value));

  @override
  void didUpdateWidget(MoneyField old) {
    super.didUpdateWidget(old);
    if (parseMoney(_c.text) != widget.value) _c.text = _fmt(widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _bump(double by) {
    final v = ((widget.value ?? 0) + by).clamp(0, 1e12).toDouble();
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final step = widget.step ?? app.country.amountStep;
    final symbol = app.cc == CountryCode.jp ? (app.s.ja ? null : '¥') : '\$';
    final suffix = app.cc == CountryCode.jp && app.s.ja ? '円' : null;
    final tt = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: tt.titleMedium),
      const SizedBox(height: 8),
      Row(children: [
        _RoundButton(icon: Icons.remove, label: '− ${app.money(step)}', onPressed: (widget.value ?? 0) > 0 ? () => _bump(-step) : null),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _c,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [_ThousandsFormatter()],
            textAlign: TextAlign.center,
            style: tt.headlineSmall,
            decoration: InputDecoration(
              hintText: widget.hint ?? '0',
              prefixText: symbol,
              suffixText: suffix,
              prefixStyle: tt.titleLarge,
              suffixStyle: tt.titleLarge,
            ),
            onChanged: (t) => widget.onChanged(parseMoney(t)),
          ),
        ),
        const SizedBox(width: 10),
        _RoundButton(icon: Icons.add, label: '+ ${app.money(step)}', onPressed: () => _bump(step)),
      ]),
      if (widget.helper != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(widget.helper!, style: tt.bodyMedium)),
    ]);
  }
}

/// Status with icon + words, never color alone.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final Status status;

  @override
  Widget build(BuildContext context) {
    if (status == Status.none) return const SizedBox.shrink();
    final st = statusStyle(status, Theme.of(context).brightness);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(st.icon, color: st.color, size: 24),
      const SizedBox(width: 6),
      Flexible(child: Text(AppScope.of(context).s.t('status.${status.name}'), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: st.color))),
    ]);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text(text, style: tt.headlineSmall)),
        if (trailing != null) Text(trailing!, style: tt.titleMedium),
      ]),
    );
  }
}

Future<bool> confirm(BuildContext context, String message, {String? yes}) async {
  final s = AppScope.of(context).s;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message, style: Theme.of(c).textTheme.bodyLarge),
      actionsOverflowDirection: VerticalDirection.up,
      actionsOverflowButtonSpacing: 8,
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('common.cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes ?? s.t('common.yes'))),
      ],
    ),
  );
  return r ?? false;
}
