import 'package:budget_compass/l10n/strings.dart';
import 'package:budget_compass/logic/location.dart';
import 'package:budget_compass/logic/models.dart';
import 'package:budget_compass/main.dart';
import 'package:budget_compass/services/locator.dart';
import 'package:budget_compass/state/app_state.dart';
import 'package:budget_compass/ui/steps.dart' as steps;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeLocator implements Locator {
  FakeLocator(this.result);
  final DetectResult result;
  int calls = 0;
  @override
  Future<DetectResult> detect() async {
    calls++;
    return result;
  }
}

/// A small phone (360 × 740 dp).
void usePhone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2220);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
}

Future<void> tapText(WidgetTester t, String text) async {
  final f = find.text(text).last;
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Scrolls the visible list from top to bottom so every item is laid out (catches overflows).
Future<void> scrollThrough(WidgetTester t) async {
  final list = find.byType(Scrollable).hitTestable().first;
  for (var i = 0; i < 40; i++) {
    await t.drag(list, const Offset(0, -500));
    await t.pump();
  }
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('first run in Japanese with extra-large text: detects Tsu, builds a plan, edits it', (t) async {
    usePhone(t);
    final fake = FakeLocator(const DetectResult(DetectStatus.found, Detected('jp:city:tsu', 1)));
    steps.locator = fake;
    final state = AppState(lang: Lang.en, inputs: const BudgetInputs(location: 'jp:national', incomeAmount: 250000));
    await t.pumpWidget(MoneyPlannerApp(state: state));
    await t.pumpAndSettle();

    // Welcome: choose Japanese and the biggest text.
    await tapText(t, '日本語');
    expect(find.text('お金の計画を、かんたんに'), findsOneWidget);
    await tapText(t, 'とても大きい');
    expect(state.textSize, TextSize.xlarge);
    await t.tap(find.text('はじめる'));
    await t.pumpAndSettle();
    await t.pumpAndSettle();

    // Location: detected automatically on arrival.
    expect(fake.calls, 1);
    expect(state.inputs.location, 'jp:city:tsu');
    expect(find.text('見つかりました：三重県 津市'), findsOneWidget);
    await t.tap(find.text('次へ'));
    await t.pumpAndSettle();

    // Income: type 280,000 after tax, monthly.
    expect(find.text('毎月いくら受け取っていますか？'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '280000');
    await t.pumpAndSettle();
    expect(state.inputs.incomeAmount, 280000);
    expect(find.text('280,000'), findsOneWidget); // thousands separators while typing
    await scrollThrough(t);
    await t.tap(find.text('次へ'));
    await t.pumpAndSettle();

    // Household: two adults.
    await t.tap(find.bySemanticsLabel('+').first);
    await t.pumpAndSettle();
    expect(state.inputs.adults, 2);
    await scrollThrough(t);
    await t.tap(find.text('次へ'));
    await t.pumpAndSettle();

    // Bills: skip, show plan.
    expect(find.text('わかっている支払いはありますか？'), findsOneWidget);
    await scrollThrough(t);
    await t.tap(find.text('プランを見る'));
    await t.pumpAndSettle();

    // Home.
    expect(state.setupDone, isTrue);
    expect(find.text('毎月使えるお金'), findsOneWidget);
    expect(find.text('280,000円'), findsOneWidget);
    expect(find.textContaining('貯金できます'), findsOneWidget);
    await scrollThrough(t);

    // Edit eating out to 0 → savings increase.
    final before = state.budget.groupTotal(Group.savings);
    final dining = state.budget.line('dining')!.amount;
    await t.drag(find.byType(Scrollable).hitTestable().first, const Offset(0, 20000));
    await t.pumpAndSettle();
    await tapText(t, '外食');
    expect(find.text('変更：外食'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, '0');
    await t.pumpAndSettle();
    await tapText(t, '保存する');
    expect(state.budget.line('dining')!.amount, 0);
    expect(state.budget.groupTotal(Group.savings), closeTo(before + dining, 1));
    expect(state.budget.unassigned, 0);

    // Other tabs render at this size without overflow.
    await t.tap(find.text('わたしの情報'));
    await t.pumpAndSettle();
    expect(find.text('三重県 津市'), findsWidgets);
    await scrollThrough(t);
    await t.tap(find.text('設定'));
    await t.pumpAndSettle();
    await scrollThrough(t);
  });

  testWidgets('English: choose what to count, add own expense, high contrast', (t) async {
    usePhone(t);
    final state = AppState(
      setupDone: true,
      textSize: TextSize.large,
      inputs: const BudgetInputs(location: 'jp:city:tsu', incomeAmount: 4600000, frequency: PayFrequency.yearly, incomeType: IncomeType.gross),
    );
    await t.pumpWidget(MoneyPlannerApp(state: state));
    await t.pumpAndSettle();
    expect(find.text('Money you have each month'), findsOneWidget);
    expect(find.textContaining('Tax and insurance'), findsOneWidget);
    final takeHome = state.budget.takeHome;

    // Turn off resident tax.
    await tapText(t, 'Choose what to count');
    expect(find.text('Resident tax'), findsOneWidget);
    await tapText(t, 'Resident tax');
    expect(state.inputs.excluded, contains('tax:resident'));
    expect(state.budget.takeHome, greaterThan(takeHome));
    // Turn off eating out.
    await tapText(t, 'Eating out');
    expect(state.budget.line('dining'), isNull);
    await scrollThrough(t);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.textContaining('Not counting Resident tax'), findsOneWidget);

    // Add an expense with an idea chip.
    await tapText(t, 'Add my own expense');
    await tapText(t, 'Medicine');
    await t.enterText(find.byType(TextField).last, '6000');
    await t.pumpAndSettle();
    await tapText(t, 'Add');
    final custom = state.budget.lines.where((l) => l.isCustom).single;
    expect(custom.customName, 'Medicine');
    expect(custom.amount, 6000);
    expect(state.budget.unassigned, 0);

    // High contrast + extra large text still lays out.
    state.setDisplay(Display.contrast);
    state.setTextSize(TextSize.xlarge);
    await t.pumpAndSettle();
    await scrollThrough(t);
  });

  testWidgets('location denied shows a plain explanation and the list still works', (t) async {
    usePhone(t);
    steps.locator = FakeLocator(const DetectResult(DetectStatus.denied));
    final state = AppState(setupDone: true, inputs: const BudgetInputs(location: 'jp:national', incomeAmount: 200000));
    await t.pumpWidget(MoneyPlannerApp(state: state));
    await t.pumpAndSettle();
    await t.tap(find.text('My details'));
    await t.pumpAndSettle();
    await t.tap(find.text('Change').first);
    await t.pumpAndSettle();
    await tapText(t, 'Find my location');
    expect(find.textContaining('did not allow'), findsOneWidget);
    await tapText(t, 'Choose from a list');
    await t.enterText(find.byType(TextField), '津');
    await t.pumpAndSettle();
    await t.tap(find.text('Tsu, Mie'));
    await t.pumpAndSettle();
    expect(state.inputs.location, 'jp:city:tsu');
  });

  testWidgets('settings survive a restart', (t) async {
    final a = AppState(setupDone: true, inputs: const BudgetInputs(location: 'jp:city:tsu', incomeAmount: 222000));
    a.setLang(Lang.ja);
    a.setTextSize(TextSize.xlarge);
    a.addCustom('薬', 3000, Group.needs);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    final b = await AppState.load(deviceLang: Lang.en, guessedLocation: null);
    expect(b.lang, Lang.ja);
    expect(b.textSize, TextSize.xlarge);
    expect(b.inputs.incomeAmount, 222000);
    expect(b.inputs.custom.single.name, '薬');
    expect(b.setupDone, isTrue);
  });
}
