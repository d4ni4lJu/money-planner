import 'package:intl/intl.dart';

import '../logic/budget.dart';
import '../logic/countries.dart';
import '../logic/models.dart';

enum Lang { en, ja }

/// All user-facing text, in plain language. Use `S.of(lang)`.
class S {
  const S(this.lang);
  final Lang lang;
  bool get ja => lang == Lang.ja;

  String t(String key, [Map<String, Object> args = const {}]) {
    var s = (ja ? _ja[key] : null) ?? _en[key] ?? key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  // ---------- numbers ----------

  static final _grouped = NumberFormat('#,##0', 'en_US');

  /// "42,900円" in Japanese, "¥42,900" / "$1,500" in English.
  String money(double v, CountryCode cc) {
    final neg = v < 0;
    final n = _grouped.format(v.abs().round());
    final s = cc == CountryCode.jp ? (ja ? '$n円' : '¥$n') : '\$$n';
    return neg ? '−$s' : s;
  }

  String pct(double v) => '${(v * 100).round()}%';

  // ---------- names ----------

  String category(CategoryLine l) => l.customName ?? categoryName(l.id);
  String categoryName(String id) => t('cat.$id');
  String taxName(String id) => t('tax.$id');
  String groupName(Group g) => t('group.${g.name}');

  String regionName(CountryCode cc, String code) {
    if (cc == CountryCode.jp && ja) return _jaPrefectures[code] ?? code;
    final r = countries[cc]!.data.regions.where((x) => x.code == code).firstOrNull;
    return r?.name ?? code;
  }

  String cityName(CountryCode cc, CityRecord c) => cc == CountryCode.jp && ja ? (_jaCities[c.id] ?? c.name) : c.name;

  /// "Tsu, Mie" / "三重県 津市" / "Mie (prefecture average)"
  String placeName(String key) {
    final cc = countryOf(key);
    final parts = key.split(':');
    final data = countries[cc]!.data;
    if (parts.length > 2 && parts[1] == 'city') {
      final c = data.cities.where((x) => x.id == parts[2]).firstOrNull;
      if (c != null) {
        final region = cc == CountryCode.us ? c.region : regionName(cc, c.region);
        return ja ? '$region ${cityName(cc, c)}' : '${cityName(cc, c)}, $region';
      }
    }
    if (parts.length > 2 && parts[1] == 'region') {
      return t(cc == CountryCode.jp ? 'place.prefAvg' : 'place.stateAvg', {'name': regionName(cc, parts[2])});
    }
    return t('place.national', {'country': t('country.${cc.name}')});
  }

  String homeSize(CountryCode cc, int bedrooms) =>
      cc == CountryCode.jp ? const ['1K・1R', '1LDK・2DK', '2LDK・3DK', '3LDK〜'][bedrooms - 1] : t('home.bedrooms', {'n': bedrooms});

  // ---------- warnings ----------

  String warning(BudgetWarning w, CountryCode cc) {
    final v = w.values;
    String m(String k) => money((v[k] as num).toDouble(), cc);
    String p(String k) => pct((v[k] as num).toDouble());
    return switch (w.code) {
      'shortfall' => t('warn.shortfall', {'amount': m('amount')}) +
          ((v['trim'] as List).isEmpty ? '' : t('warn.trim', {'items': (v['trim'] as List).map((id) => categoryName('$id')).join(ja ? '、' : ' and ')})),
      'housingShare' => t('warn.housingShare', {'pct': p('pct')}),
      'rentHigh' => t('warn.rentHigh', {'pct': p('pct'), 'typical': m('typical')}),
      'debtHigh' => t('warn.debtHigh', {'pct': p('pct')}),
      'taxesOff' => t('warn.taxesOff', {'items': (v['ids'] as List).map((id) => taxName('$id')).join(ja ? '、' : ', '), 'amount': m('amount')}),
      'leftover' => t('warn.leftover', {'amount': m('amount')}),
      'lowSavings' => t('warn.lowSavings', {'pct': p('pct')}),
      'healthy' => t('warn.healthy', {'pct': p('pct')}),
      _ => t('warn.noIncome'),
    };
  }

  static const _en = <String, String>{
    'app.title': 'Money Planner',
    'common.next': 'Next',
    'common.back': 'Back',
    'common.save': 'Save',
    'common.cancel': 'Cancel',
    'common.done': 'Done',
    'common.change': 'Change',
    'common.yes': 'Yes',
    'common.no': 'No',
    'common.skip': 'Skip this step',
    'common.step': 'Step {n} of {total}',
    'common.perMonth': 'per month',
    'common.perYear': '{amount} per year',

    'nav.budget': 'My plan',
    'nav.info': 'My details',
    'nav.settings': 'Settings',

    'welcome.title': 'Plan your money, simply',
    'welcome.body': 'Answer a few easy questions. We will show how much you can spend on rent, food and other things each month, based on where you live.',
    'welcome.start': 'Start',
    'welcome.language': 'Language',
    'welcome.textSize': 'Text size',

    'loc.title': 'Where do you live?',
    'loc.body': 'Prices are different in each area. We can find your area automatically.',
    'loc.find': 'Find my location',
    'loc.finding': 'Looking for your location…',
    'loc.choose': 'Choose from a list',
    'loc.selected': 'Your area',
    'loc.found': 'Found: {place}',
    'loc.foundNear': 'Found: {place} (the nearest city we know, {km} km away)',
    'loc.foundRegion': 'Found: {place}. Using average prices for your area.',
    'loc.denied': 'Your phone did not allow us to see your location. You can choose your area from the list instead.',
    'loc.off': 'Location is turned off on this device. You can choose your area from the list instead.',
    'loc.notCovered': 'Sorry, your area is not available yet (Japan and the U.S. only). Please choose the closest place from the list.',
    'loc.error': 'We could not find your location. Please choose your area from the list.',
    'loc.search': 'Type a city or area name',
    'loc.cities': 'Cities',
    'loc.regionsJp': 'Other areas (prefecture average)',
    'loc.regionsUs': 'Other areas (state average)',
    'loc.noResults': 'Nothing found. Try another name.',

    'income.title': 'How much money do you receive?',
    'income.body': 'Include your salary, pension and any other regular income.',
    'income.afterTax': 'After tax',
    'income.afterTaxHint': 'The amount that arrives in your bank (easiest)',
    'income.beforeTax': 'Before tax',
    'income.beforeTaxHint': 'The total on your contract, before tax is taken',
    'income.amount': 'Amount',
    'income.howOften': 'How often?',
    'income.married': 'Do you support a husband or wife who earns little or nothing?',
    'freq.monthly': 'Every month',
    'freq.biweekly': 'Every 2 weeks',
    'freq.semimonthly': 'Twice a month',
    'freq.weekly': 'Every week',
    'freq.yearly': 'Every year',

    'house.title': 'Who lives with you?',
    'house.adults': 'Adults (including you)',
    'house.children': 'Children',
    'house.childcare': 'Children in paid daycare',
    'house.car': 'Do you have a car?',

    'bills.title': 'Do you know any of your bills?',
    'bills.body': 'This is optional. If you leave a box empty, we will use the usual cost in your area.',
    'bills.rent': 'Rent or home loan (per month)',
    'bills.rentHint': 'Usual for a {home} in your area: {amount}',
    'bills.health': 'Medical costs and medicine (per month)',
    'bills.debt': 'Loan repayments (per month)',
    'bills.carPayment': 'Car loan (per month)',
    'bills.subscriptions': 'Subscriptions (per month)',
    'bills.unknown': 'Leave empty to use the usual cost',
    'bills.finish': 'Show my plan',

    'home.greeting': 'Your monthly plan',
    'home.income': 'Money you have each month',
    'home.afterTax': 'after tax',
    'home.taxLine': 'Before tax {gross}  ·  Tax and insurance {tax}',
    'home.canSave': 'You can save {amount} each month',
    'home.canSaveSub': 'That is {year} in a year.',
    'home.short': 'You are short {amount} each month',
    'home.shortSub': 'Your costs are more than your income. Look at the red items below.',
    'home.leftover': '{amount} is not planned yet',
    'home.where': 'Where your money goes',
    'home.tapHint': 'Tap any item to change it.',
    'home.usual': 'Usual here: {amount}',
    'home.yourCost': 'Your own amount',
    'home.addOwn': 'Add my own expense',
    'home.whatCounts': 'Choose what to count',
    'home.resetEdits': 'Undo my changes',
    'home.resetEditsConfirm': 'Go back to the suggested amounts?',
    'home.disclaimer': 'These are estimates to help you plan. They are not financial advice. Prices and taxes are approximate ({year} data).',
    'home.bedrooms': '{n}-bedroom home',
    'home.typicalSalary': 'We filled in a typical amount. Please change it to your own.',

    'edit.title': 'Change: {name}',
    'edit.usual': 'Usual cost where you live: {amount}',
    'edit.amount': 'Amount per month',
    'edit.remove': 'Do not count this',
    'edit.removeConfirm': 'Stop counting "{name}"? You can turn it back on in "Choose what to count".',
    'edit.delete': 'Delete this expense',
    'edit.name': 'Name',

    'add.title': 'Add my own expense',
    'add.name': 'What is it for?',
    'add.ideas': 'Ideas',
    'add.need': 'I must pay this',
    'add.want': 'Nice to have',
    'add.save': 'Add',
    'add.idea.pet': 'Pet',
    'add.idea.gifts': 'Gifts',
    'add.idea.medicine': 'Medicine',
    'add.idea.class': 'Lessons',
    'add.idea.travel': 'Travel',
    'add.idea.family': 'Family support',

    'include.title': 'Choose what to count',
    'include.body': 'Turn off anything you do not want in your plan.',
    'include.taxes': 'Tax and insurance taken from your pay',
    'include.taxesNet': 'You entered your income after tax, so tax is already taken out.',
    'include.mine': 'Added by you',
    'include.deleteConfirm': 'Delete "{name}"?',

    'info.title': 'My details',
    'info.location': 'Where I live',
    'info.income': 'My income',
    'info.household': 'My household',
    'info.bills': 'Bills I know',
    'info.billsNone': 'None entered (using usual costs)',
    'info.adults': '{n} adult(s)',
    'info.children': '{n} child(ren)',
    'info.car': 'Has a car',
    'info.noCar': 'No car',

    'settings.title': 'Settings',
    'settings.textSize': 'Text size',
    'settings.size.normal': 'Standard',
    'settings.size.large': 'Large',
    'settings.size.xlarge': 'Extra large',
    'settings.display': 'Screen colors',
    'settings.display.light': 'Light',
    'settings.display.dark': 'Dark',
    'settings.display.contrast': 'High contrast (easiest to read)',
    'settings.language': 'Language',
    'settings.method': 'How to plan',
    'method.realistic': 'Real local prices (recommended)',
    'method.realisticHint': 'Uses what things usually cost where you live. Money left over goes to savings.',
    'method.rule503020': 'Simple rule: 50 / 30 / 20',
    'method.rule503020Hint': 'Half for needs, 30% for nice-to-haves, 20% for savings.',
    'method.payYourselfFirst': 'Save first',
    'method.payYourselfFirstHint': 'Put 25% into savings first, then plan the rest.',
    'settings.startOver': 'Start over',
    'settings.startOverConfirm': 'This deletes all your answers and changes. Are you sure?',
    'settings.about': 'About these numbers',
    'settings.sources': 'Sources',

    'group.needs': 'Needs',
    'group.wants': 'Nice to have',
    'group.savings': 'Savings',

    'status.good': 'OK',
    'status.tight': 'A little low',
    'status.short': 'Too low',
    'status.high': 'Higher than usual',

    'cat.housing': 'Rent or home loan',
    'cat.utilities': 'Electricity, gas, water & phone',
    'cat.groceries': 'Food shopping',
    'cat.transportation': 'Transport & car costs',
    'cat.carPayment': 'Car loan',
    'cat.healthcare': 'Medical & medicine',
    'cat.childcare': 'Childcare',
    'cat.debt': 'Loan repayments',
    'cat.buffer': 'Spare money for surprises',
    'cat.dining': 'Eating out',
    'cat.entertainment': 'Hobbies & fun',
    'cat.personal': 'Clothes & personal items',
    'cat.subscriptions': 'Subscriptions',
    'cat.emergency': 'Emergency savings',
    'cat.investing': 'Savings for the future',

    'tax.federal': 'Federal income tax',
    'tax.fica': 'Social Security & Medicare',
    'tax.state': 'State income tax',
    'tax.local': 'City tax',
    'tax.income': 'Income tax',
    'tax.resident': 'Resident tax',
    'tax.pension': 'Pension contributions',
    'tax.health': 'Health insurance',
    'tax.employment': 'Employment insurance',

    'country.jp': 'Japan',
    'country.us': 'United States',
    'place.prefAvg': '{name} (prefecture average)',
    'place.stateAvg': '{name} (state average)',
    'place.national': '{country} (national average)',
    'place.switched': 'Your amounts were changed to {currency}. Please check your income.',

    'warn.shortfall': 'Your costs are {amount} more than your income each month.',
    'warn.trim': ' You could spend less on {items}.',
    'warn.housingShare': 'Your rent is {pct} of your income before tax. Most people try to keep it under 30%.',
    'warn.rentHigh': 'Your rent is {pct} higher than usual in your area (about {typical}).',
    'warn.debtHigh': 'Loan repayments take {pct} of your income. This makes saving hard. Pay off the loan with the highest interest first.',
    'warn.taxesOff': 'Not counting {items} ({amount} a month). Your real take-home money may be lower.',
    'warn.leftover': '{amount} a month is not planned for anything, because savings are turned off.',
    'warn.lowSavings': 'You are saving {pct} of your income. Try to save at least 10%.',
    'warn.healthy': 'Well done! You are saving {pct} of your income.',
    'warn.noIncome': 'Enter your income to see your plan.',
  };

  static const _ja = <String, String>{
    'app.title': 'かんたん家計プラン',
    'common.next': '次へ',
    'common.back': '戻る',
    'common.save': '保存する',
    'common.cancel': 'やめる',
    'common.done': '完了',
    'common.change': '変更する',
    'common.yes': 'はい',
    'common.no': 'いいえ',
    'common.skip': 'このステップをとばす',
    'common.step': 'ステップ {n} / {total}',
    'common.perMonth': '1か月あたり',
    'common.perYear': '1年で {amount}',

    'nav.budget': 'プラン',
    'nav.info': 'わたしの情報',
    'nav.settings': '設定',

    'welcome.title': 'お金の計画を、かんたんに',
    'welcome.body': 'かんたんな質問に答えるだけで、お住まいの地域に合わせて、家賃や食費などに毎月いくら使えるかをお知らせします。',
    'welcome.start': 'はじめる',
    'welcome.language': '言語 / Language',
    'welcome.textSize': '文字の大きさ',

    'loc.title': 'どこにお住まいですか？',
    'loc.body': '物価は地域によってちがいます。お住まいの地域を自動で調べることができます。',
    'loc.find': '現在地を調べる',
    'loc.finding': '現在地を調べています…',
    'loc.choose': '一覧から選ぶ',
    'loc.selected': 'お住まいの地域',
    'loc.found': '見つかりました：{place}',
    'loc.foundNear': '見つかりました：{place}（いちばん近い市、{km}km）',
    'loc.foundRegion': '見つかりました：{place}。地域の平均的な物価を使います。',
    'loc.denied': '位置情報の利用が許可されませんでした。一覧から地域を選んでください。',
    'loc.off': 'この端末の位置情報がオフになっています。一覧から地域を選んでください。',
    'loc.notCovered': '申し訳ありません。お住まいの地域にはまだ対応していません（日本とアメリカのみ）。いちばん近い場所を一覧から選んでください。',
    'loc.error': '現在地がわかりませんでした。一覧から地域を選んでください。',
    'loc.search': '市や県の名前を入力',
    'loc.cities': '市',
    'loc.regionsJp': 'その他の地域（都道府県の平均）',
    'loc.regionsUs': 'その他の地域（州の平均）',
    'loc.noResults': '見つかりません。別の名前で探してください。',

    'income.title': '毎月いくら受け取っていますか？',
    'income.body': 'お給料、年金、そのほか毎月の収入を合わせてください。',
    'income.afterTax': '手取り',
    'income.afterTaxHint': '銀行口座に振り込まれる金額（いちばんかんたん）',
    'income.beforeTax': '額面（税込み）',
    'income.beforeTaxHint': '税金や保険料が引かれる前の金額',
    'income.amount': '金額',
    'income.howOften': 'どのくらいの間隔で？',
    'income.married': '収入がほとんどない配偶者を養っていますか？',
    'freq.monthly': '毎月',
    'freq.biweekly': '2週間ごと',
    'freq.semimonthly': '月に2回',
    'freq.weekly': '毎週',
    'freq.yearly': '1年間の合計',

    'house.title': 'だれと住んでいますか？',
    'house.adults': '大人（ご本人を含む）',
    'house.children': '子ども',
    'house.childcare': '保育園に通う子ども',
    'house.car': '車を持っていますか？',

    'bills.title': 'わかっている支払いはありますか？',
    'bills.body': '入力しなくてもだいじょうぶです。空らんの場合は、お住まいの地域のふつうの金額を使います。',
    'bills.rent': '家賃・住宅ローン（毎月）',
    'bills.rentHint': 'この地域の{home}のふつうの家賃：{amount}',
    'bills.health': '医療費・薬代（毎月）',
    'bills.debt': '借金の返済（毎月）',
    'bills.carPayment': '車のローン（毎月）',
    'bills.subscriptions': 'サブスク（毎月）',
    'bills.unknown': '空らんのままでOK（ふつうの金額を使います）',
    'bills.finish': 'プランを見る',

    'home.greeting': '毎月のお金のプラン',
    'home.income': '毎月使えるお金',
    'home.afterTax': '手取り',
    'home.taxLine': '額面 {gross}　・　税金と保険料 {tax}',
    'home.canSave': '毎月 {amount} 貯金できます',
    'home.canSaveSub': '1年で {year} になります。',
    'home.short': '毎月 {amount} 足りません',
    'home.shortSub': '支出が収入より多くなっています。下の赤い項目を見直しましょう。',
    'home.leftover': '{amount} がまだ使いみち未定です',
    'home.where': 'お金の使いみち',
    'home.tapHint': '項目をタップすると金額を変えられます。',
    'home.usual': 'この地域のふつう：{amount}',
    'home.yourCost': 'ご自分で入力した金額',
    'home.addOwn': '自分の支出を追加する',
    'home.whatCounts': '計算にふくめるものを選ぶ',
    'home.resetEdits': '変更を元にもどす',
    'home.resetEditsConfirm': 'おすすめの金額にもどしますか？',
    'home.disclaimer': 'この金額は計画のための目安です。金融に関する助言ではありません。物価や税金はおおよその数字です（{year}年のデータ）。',
    'home.bedrooms': '{n}部屋の家',
    'home.typicalSalary': 'ふつうの金額を入れてあります。ご自分の金額に変えてください。',

    'edit.title': '変更：{name}',
    'edit.usual': 'お住まいの地域のふつうの金額：{amount}',
    'edit.amount': '1か月の金額',
    'edit.remove': 'この項目を計算に入れない',
    'edit.removeConfirm': '「{name}」を計算から外しますか？「計算にふくめるものを選ぶ」からいつでも戻せます。',
    'edit.delete': 'この支出を削除する',
    'edit.name': '名前',

    'add.title': '自分の支出を追加する',
    'add.name': '何に使うお金ですか？',
    'add.ideas': '例',
    'add.need': '必ず払うもの',
    'add.want': 'あるとうれしいもの',
    'add.save': '追加する',
    'add.idea.pet': 'ペット',
    'add.idea.gifts': 'プレゼント・お祝い',
    'add.idea.medicine': '薬',
    'add.idea.class': '習いごと',
    'add.idea.travel': '旅行',
    'add.idea.family': '家族への仕送り',

    'include.title': '計算にふくめるものを選ぶ',
    'include.body': 'プランに入れたくないものはオフにしてください。',
    'include.taxes': 'お給料から引かれる税金と保険料',
    'include.taxesNet': '手取りの金額を入力したので、税金はすでに引かれています。',
    'include.mine': 'ご自分で追加したもの',
    'include.deleteConfirm': '「{name}」を削除しますか？',

    'info.title': 'わたしの情報',
    'info.location': '住んでいる地域',
    'info.income': '収入',
    'info.household': '家族',
    'info.bills': 'わかっている支払い',
    'info.billsNone': '入力なし（ふつうの金額を使用）',
    'info.adults': '大人 {n}人',
    'info.children': '子ども {n}人',
    'info.car': '車あり',
    'info.noCar': '車なし',

    'settings.title': '設定',
    'settings.textSize': '文字の大きさ',
    'settings.size.normal': 'ふつう',
    'settings.size.large': '大きい',
    'settings.size.xlarge': 'とても大きい',
    'settings.display': '画面の色',
    'settings.display.light': '明るい',
    'settings.display.dark': '暗い',
    'settings.display.contrast': 'くっきり（いちばん見やすい）',
    'settings.language': '言語 / Language',
    'settings.method': '計画の立て方',
    'method.realistic': '地域の実際の物価で（おすすめ）',
    'method.realisticHint': 'お住まいの地域のふつうの金額を使います。残ったお金は貯金にまわします。',
    'method.rule503020': 'かんたんルール：50 / 30 / 20',
    'method.rule503020Hint': '半分を必要な支出、30%をゆとりの支出、20%を貯金にします。',
    'method.payYourselfFirst': '先に貯金する',
    'method.payYourselfFirstHint': 'まず25%を貯金して、残りで計画します。',
    'settings.startOver': '最初からやり直す',
    'settings.startOverConfirm': '入力したすべての内容が消えます。よろしいですか？',
    'settings.about': 'この数字について',
    'settings.sources': '出典',

    'group.needs': '必要な支出',
    'group.wants': 'ゆとりの支出',
    'group.savings': '貯金',

    'status.good': 'じゅうぶん',
    'status.tight': '少し少なめ',
    'status.short': '足りない',
    'status.high': 'ふつうより高い',

    'cat.housing': '家賃・住宅ローン',
    'cat.utilities': '電気・ガス・水道・電話',
    'cat.groceries': '食費（食料品）',
    'cat.transportation': '交通費・車の費用',
    'cat.carPayment': '車のローン',
    'cat.healthcare': '医療費・薬代',
    'cat.childcare': '保育料',
    'cat.debt': '借金の返済',
    'cat.buffer': 'もしものための予備費',
    'cat.dining': '外食',
    'cat.entertainment': '趣味・娯楽',
    'cat.personal': '衣服・日用品',
    'cat.subscriptions': 'サブスク',
    'cat.emergency': '緊急用の貯金',
    'cat.investing': '将来のための貯金',

    'tax.federal': '連邦所得税',
    'tax.fica': '社会保障税・メディケア税',
    'tax.state': '州所得税',
    'tax.local': '市税',
    'tax.income': '所得税',
    'tax.resident': '住民税',
    'tax.pension': '厚生年金保険料',
    'tax.health': '健康保険料',
    'tax.employment': '雇用保険料',

    'country.jp': '日本',
    'country.us': 'アメリカ',
    'place.prefAvg': '{name}（県の平均）',
    'place.stateAvg': '{name}（州の平均）',
    'place.national': '{country}（全国平均）',
    'place.switched': '金額を{currency}に変えました。収入をご確認ください。',

    'warn.shortfall': '毎月、支出が収入より {amount} 多くなっています。',
    'warn.trim': '{items}を少し減らしてみましょう。',
    'warn.housingShare': '家賃が額面収入の{pct}です。30%以下がひとつの目安です。',
    'warn.rentHigh': '家賃がこの地域のふつう（約{typical}）より{pct}高いです。',
    'warn.debtHigh': '借金の返済が収入の{pct}をしめています。金利の高い借金から先に返しましょう。',
    'warn.taxesOff': '{items}（毎月{amount}）を計算に入れていません。実際の手取りはもっと少ないかもしれません。',
    'warn.leftover': '貯金をオフにしているため、毎月{amount}の使いみちが決まっていません。',
    'warn.lowSavings': '貯金は収入の{pct}です。少なくとも10%を目指しましょう。',
    'warn.healthy': 'すばらしいです！収入の{pct}を貯金できています。',
    'warn.noIncome': '収入を入力すると、プランが表示されます。',
  };

  static const _jaPrefectures = {
    '01': '北海道', '02': '青森県', '03': '岩手県', '04': '宮城県', '05': '秋田県', '06': '山形県', '07': '福島県',
    '08': '茨城県', '09': '栃木県', '10': '群馬県', '11': '埼玉県', '12': '千葉県', '13': '東京都', '14': '神奈川県',
    '15': '新潟県', '16': '富山県', '17': '石川県', '18': '福井県', '19': '山梨県', '20': '長野県', '21': '岐阜県',
    '22': '静岡県', '23': '愛知県', '24': '三重県', '25': '滋賀県', '26': '京都府', '27': '大阪府', '28': '兵庫県',
    '29': '奈良県', '30': '和歌山県', '31': '鳥取県', '32': '島根県', '33': '岡山県', '34': '広島県', '35': '山口県',
    '36': '徳島県', '37': '香川県', '38': '愛媛県', '39': '高知県', '40': '福岡県', '41': '佐賀県', '42': '長崎県',
    '43': '熊本県', '44': '大分県', '45': '宮崎県', '46': '鹿児島県', '47': '沖縄県',
  };

  static const _jaCities = {
    'tokyo': '東京23区', 'yokohama': '横浜市', 'kawasaki': '川崎市', 'saitama': 'さいたま市', 'chiba': '千葉市',
    'osaka': '大阪市', 'kyoto': '京都市', 'kobe': '神戸市', 'nagoya': '名古屋市', 'sapporo': '札幌市', 'sendai': '仙台市',
    'fukuoka': '福岡市', 'hiroshima': '広島市', 'tsu': '津市', 'yokkaichi': '四日市市', 'suzuka': '鈴鹿市',
    'matsusaka': '松阪市', 'ise': '伊勢市', 'nara': '奈良市', 'gifu': '岐阜市', 'shizuoka': '静岡市', 'hamamatsu': '浜松市',
    'niigata': '新潟市', 'kanazawa': '金沢市', 'okayama': '岡山市', 'kumamoto': '熊本市', 'kagoshima': '鹿児島市',
    'matsuyama': '松山市', 'naha': '那覇市',
  };

  /// Every name a place can be searched by (English, Japanese).
  static List<String> searchNames(CountryCode cc, String name, String code, {bool city = true}) => [
        name.toLowerCase(),
        if (cc == CountryCode.jp) (city ? _jaCities[code] : _jaPrefectures[code]) ?? '',
      ];
}
