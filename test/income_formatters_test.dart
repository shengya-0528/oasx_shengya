import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:oasx/modules/home/widgets/income_formatters.dart';
import 'package:oasx/translation/i18n.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.addTranslations(Messages().keys);
    Get.locale = const Locale('zh', 'CN');
  });
  tearDown(() => Get.reset());

  test('quantity uses 万 and 亿 like the game UI', () {
    expect(formatIncomeQuantity(0), '0');
    expect(formatIncomeQuantity(1423), '1423');
    expect(formatIncomeQuantity(17800), '1.78万');
    expect(formatIncomeQuantity(63400), '6.34万');
    expect(formatIncomeQuantity(12288900), '1228.89万');
    expect(formatIncomeQuantity(200000000), '2.00亿');
    // 读不到的 -1 显示成 --，不能拿 0 顶替，否则差值会凭空多出来
    expect(formatIncomeQuantity(-1), '--');
  });

  test('delta hides a missing baseline and greys a same-day zero', () {
    expect(formatIncomeDelta(null), isNull);

    final zero = formatIncomeDelta(0)!;
    expect(zero.text, '0');
    expect(zero.unchanged, isTrue);

    final up = formatIncomeDelta(528000)!;
    expect(up.text, '↑+52.80万');
    expect(up.increase, isTrue);
    expect(up.unchanged, isFalse);

    final down = formatIncomeDelta(-1375)!;
    expect(down.text, '↓-1375');
    expect(down.increase, isFalse);
    expect(down.unchanged, isFalse);
  });

  test('header labels use the panel formats', () {
    expect(formatIncomeDayLabel('2026-10-17'), '10-17');
    expect(formatIncomeDayLabel('nonsense'), 'nonsense');
    expect(formatIncomeClock('2026-10-17 15:09:31'), '15:09');
    expect(formatIncomeClock(''), '');
  });

  test('compare baselines are day, week and month', () {
    expect(formatIncomeCompareDays(1), '日环比');
    expect(formatIncomeCompareDays(7), '周环比');
    expect(formatIncomeCompareDays(30), '月环比');
    // 后端将来加了别的窗口，先原样显示数字，不要空白
    expect(formatIncomeCompareDays(10), '10');
  });

  test('fields keep the backend order and a localized label', () {
    expect(incomeItemFields, [
      'gold',
      'jade',
      'ap',
      'auto_point',
      'honor',
      'medal',
      'contrib',
      'broken_amulet',
      'mystery_amulet',
      'sca_orochi_scales',
      'sca_reverse_scale',
      'sca_demon_souls',
      'hyakki_ticket',
      'daruma',
      'daruma_shard',
      'qiyi',
    ]);
    expect(incomeItemLabel('gold'), '金币');
    expect(incomeItemLabel('mystery_amulet'), '神秘的符咒');
    // 后端先加字段、前端还没补翻译时显示字段名，不要让卡片变成空白
    expect(incomeItemLabel('brand_new_field'), 'brand_new_field');
  });

  test('every income field resolves to its shipped icon', () {
    expect(incomeItemIcon('gold'), 'assets/images/income/gold.png');
    expect(
      incomeItemIcon('mystery_amulet'),
      'assets/images/income/mystery_amulet.png',
    );
    expect(incomeItemIcon('qiyi'), 'assets/images/income/qiyi.png');
    // 16 个字段都有图；以后后端加字段时这里会先失败，提醒补图
    final withIcon = incomeItemFields.where(
      (field) => incomeItemIcon(field) != null,
    );
    expect(withIcon.length, incomeItemFields.length);
    expect(incomeItemIcon('brand_new_field'), isNull);
  });
}
