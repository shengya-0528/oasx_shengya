import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/home/models/script_income_models.dart';

void main() {
  test('parses one day snapshot with its first read', () {
    final day = ScriptIncomeDay.fromJson({
      'script_name': 'oas1',
      'date': '2026-10-17',
      'collected_at': '2026-10-17 15:09:31',
      'first_dt': '2026-10-17 03:00:00',
      'baseline_date': '2026-10-16',
      'items': [
        {
          'name': 'gold',
          'value': 12288900,
          'delta': 528000,
          'first': 11760900,
          'delta_first': 528000,
        },
        {
          'name': 'ap',
          'value': -1,
          'delta': null,
          'first': -1,
          'delta_first': null,
        },
      ],
    });
    expect(day.scriptName, 'oas1');
    expect(day.dateKey, '2026-10-17');
    expect(day.collectedAt, '2026-10-17 15:09:31');
    expect(day.hasFirstRead, isTrue);
    expect(day.items.length, 2);

    final gold = day.itemFor('gold')!;
    expect(gold.value, 12288900);
    expect(gold.delta, 528000);
    expect(gold.first, 11760900);
    expect(gold.deltaFirst, 528000);
    expect(gold.hasValue, isTrue);

    final ap = day.itemFor('ap')!;
    expect(ap.value, -1);
    expect(ap.hasValue, isFalse);
    expect(ap.deltaFirst, isNull);
    expect(day.itemFor('jade'), isNull);
  });

  test('rows written before the first-read feature stay baseline-free', () {
    final day = ScriptIncomeDay.fromJson({
      'script_name': 'oas1',
      'items': <dynamic>[],
    }, dateKey: '2026-10-16');
    expect(day.dateKey, '2026-10-16');
    expect(day.firstReadAt, isEmpty);
    expect(day.hasFirstRead, isFalse);
    expect(day.items, isEmpty);
  });

  test('tolerates numeric strings and junk rows', () {
    final day = ScriptIncomeDay.fromJson({
      'script_name': 'oas1',
      'items': [
        'junk',
        {'name': 'jade', 'value': '1423', 'delta_first': '157'},
      ],
    });
    expect(day.items.length, 1);
    expect(day.items.single.name, 'jade');
    expect(day.items.single.value, 1423);
    expect(day.items.single.deltaFirst, 157);
    expect(day.items.single.delta, isNull);
  });

  test('parses the available dates newest first', () {
    final list = ScriptIncomeDateList.fromJson({
      'script_name': 'oas1',
      'dates': ['2026-10-18', '2026-10-17', 3, ''],
    });
    expect(list.scriptName, 'oas1');
    expect(list.dates, ['2026-10-18', '2026-10-17', '3']);
  });
}
