import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../logic/budget.dart';
import '../logic/countries.dart';
import '../logic/models.dart';

enum TextSize {
  normal(1.0),
  large(1.25),
  xlarge(1.5);

  const TextSize(this.scale);
  final double scale;
}

enum Display { light, dark, contrast }

/// Everything the app remembers, with saving to the device.
class AppState extends ChangeNotifier {
  AppState({BudgetInputs? inputs, this.lang = Lang.en, this.textSize = TextSize.large, this.display = Display.light, this.setupDone = false})
      : _inputs = inputs ?? const BudgetInputs();

  static const _key = 'money_planner_v1';

  BudgetInputs _inputs;
  Map<String, double> _edits = {};
  Lang lang;
  TextSize textSize;
  Display display;
  bool setupDone;

  /// A short message to show once (e.g. after switching country).
  String? notice;

  Budget? _budget;

  BudgetInputs get inputs => _inputs;
  Map<String, double> get edits => _edits;
  S get s => S(lang);
  Country get country => countries[countryOf(_inputs.location)]!;
  CountryCode get cc => country.code;
  Budget get budget => _budget ??= applyEdits(buildBudget(_inputs), _edits);
  List<BudgetWarning> get budgetWarnings => warnings(budget, _inputs);
  String money(double v) => s.money(v, cc);

  void _changed() {
    _budget = null;
    notifyListeners();
    _save();
  }

  void update(BudgetInputs Function(BudgetInputs) f) {
    _inputs = f(_inputs);
    _changed();
  }

  void setLocation(String key) {
    final r = switchLocation(_inputs, key);
    _inputs = r.inputs;
    if (r.countryChanged) {
      _edits = {};
      notice = s.t('place.switched', {'currency': country.currency});
    }
    _changed();
  }

  void editCategory(String id, double amount) {
    _edits = {..._edits}
      ..remove(id)
      ..[id] = amount;
    _changed();
  }

  void resetEdits() {
    _edits = {};
    _changed();
  }

  void setIncluded(String key, bool included) {
    final ex = {..._inputs.excluded};
    included ? ex.remove(key) : ex.add(key);
    _edits = {..._edits}..remove(key);
    update((i) => i.copyWith(excluded: ex));
  }

  void addCustom(String name, double amount, Group group) {
    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    update((i) => i.copyWith(custom: [...i.custom, CustomItem(id: id, name: name, amount: amount, group: group)]));
  }

  void updateCustom(String id, {String? name, double? amount}) {
    _edits = {..._edits}..remove('custom:$id');
    update((i) => i.copyWith(custom: [for (final c in i.custom) c.id == id ? c.copyWith(name: name, amount: amount) : c]));
  }

  void deleteCustom(String id) {
    _edits = {..._edits}..remove('custom:$id');
    update((i) => i.copyWith(
          custom: i.custom.where((c) => c.id != id).toList(),
          excluded: {...i.excluded}..remove('custom:$id'),
        ));
  }

  void setLang(Lang v) {
    lang = v;
    _changed();
  }

  void setTextSize(TextSize v) {
    textSize = v;
    _changed();
  }

  void setDisplay(Display v) {
    display = v;
    _changed();
  }

  void finishSetup() {
    setupDone = true;
    _changed();
  }

  void startOver() {
    final keepLocation = _inputs.location;
    _inputs = BudgetInputs(location: keepLocation, incomeAmount: country.defaultMonthlyNet);
    _edits = {};
    setupDone = false;
    _changed();
  }

  void clearNotice() => notice = null;

  // ---------- persistence ----------

  Map<String, dynamic> toJson() => {
        'inputs': _inputs.toJson(),
        'edits': _edits,
        'lang': lang.name,
        'textSize': textSize.name,
        'display': display.name,
        'setupDone': setupDone,
      };

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Could not save: $e');
    }
  }

  /// Loads saved state, or makes a first-run state guessed from the device.
  static Future<AppState> load({required Lang deviceLang, required String? guessedLocation}) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        T pick<T extends Enum>(List<T> v, Object? n, T d) => v.firstWhere((x) => x.name == n, orElse: () => d);
        return AppState(
          inputs: BudgetInputs.fromJson(Map<String, dynamic>.from(j['inputs'] as Map)),
          lang: pick(Lang.values, j['lang'], deviceLang),
          textSize: pick(TextSize.values, j['textSize'], TextSize.large),
          display: pick(Display.values, j['display'], Display.light),
          setupDone: j['setupDone'] == true,
        ).._edits = {
            for (final e in (j['edits'] as Map? ?? {}).entries) '${e.key}': (e.value as num).toDouble(),
          };
      }
    } catch (e) {
      debugPrint('Could not load saved data: $e');
    }
    final location = guessedLocation ?? (deviceLang == Lang.ja ? 'jp:national' : 'us:national');
    return AppState(
      lang: deviceLang,
      inputs: BudgetInputs(location: location, incomeAmount: countries[countryOf(location)]!.defaultMonthlyNet),
    );
  }
}
