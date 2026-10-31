import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Backend field order rendered by the income panel.
const List<String> incomeItemFields = <String>[
  'gold',
  'jade',
  'ap',
  'sca_orochi_scales',
  'sca_reverse_scale',
  'sca_demon_souls',
  'sca_picture_book',
  'mystery_amulet',
];

/// Translation key of every known income field.
const Map<String, String> _incomeItemLabelKeys = <String, String>{
  'gold': I18n.incomeGold,
  'jade': I18n.incomeJade,
  'ap': I18n.incomeAp,
  'sca_orochi_scales': I18n.incomeScaOrochiScales,
  'sca_reverse_scale': I18n.incomeScaReverseScale,
  'sca_demon_souls': I18n.incomeScaDemonSouls,
  'sca_picture_book': I18n.incomeScaPictureBook,
  'mystery_amulet': I18n.incomeMysteryAmulet,
};

/// Resolves the localized label of one income field.
///
/// Falls back to the raw field name when the backend ships a new field before
/// the frontend translation exists, so the amount never disappears silently.
String incomeItemLabel(String field) {
  final key = _incomeItemLabelKeys[field];
  if (key == null) {
    return field;
  }
  final label = key.tr;
  return label.isEmpty || label == key ? field : label;
}

/// Icon asset shipped for every income field that has artwork.
///
/// 文件名沿用主人给的叫法（`鱼皮.png` = 被遗忘的绘本），其余按后端字段名。
/// 新图标到位后往这里补一条、把 png 放进 `assets/images/income/` 即可
/// （整个目录已在 `pubspec.yaml` 里声明）。
const Map<String, String> _incomeItemIcons = <String, String>{
  'gold': 'assets/images/income/gold.png',
  'jade': 'assets/images/income/jade.png',
  'ap': 'assets/images/income/ap.png',
  'sca_orochi_scales': 'assets/images/income/sca_orochi_scales.png',
  'sca_reverse_scale': 'assets/images/income/sca_reverse_scale.png',
  'sca_demon_souls': 'assets/images/income/sca_demon_souls.png',
  'sca_picture_book': 'assets/images/income/鱼皮.png',
  'mystery_amulet': 'assets/images/income/mystery_amulet.png',
};

/// Resolves the icon asset path of one income field.
///
/// Returns null when the field has no artwork yet, so the card renders its
/// label alone instead of a broken image box.
String? incomeItemIcon(String field) => _incomeItemIcons[field];

/// Formats one resource amount the way the game UI reads it.
///
/// 1 亿以上按 `x.xx亿`、1 万以上按 `x.xx万`，其余原样输出；没读到的 `-1`
/// 显示成 `--`，不要拿 0 顶替，否则差值会凭空多出来。
String formatIncomeQuantity(int value) {
  if (value < 0) {
    return '--';
  }
  if (value >= 100000000) {
    return '${(value / 100000000).toStringAsFixed(2)}亿';
  }
  if (value >= 10000) {
    return '${(value / 10000).toStringAsFixed(2)}万';
  }
  return '$value';
}

/// One rendered change against the day's first read.
class IncomeDeltaDisplay {
  /// Creates one delta display.
  const IncomeDeltaDisplay({
    required this.text,
    required this.increase,
    required this.unchanged,
  });

  /// Text rendered next to the amount.
  final String text;

  /// Whether the amount grew during the day.
  final bool increase;

  /// Whether the amount stayed the same.
  final bool unchanged;
}

/// Formats the change against the day's first read.
///
/// Returns null when the day has no first-read baseline (rows written before
/// the feature, or a value that could not be read), so the panel leaves the
/// slot empty instead of showing a fake `0`.
IncomeDeltaDisplay? formatIncomeDelta(int? delta) {
  if (delta == null) {
    return null;
  }
  if (delta == 0) {
    return const IncomeDeltaDisplay(
      text: '0',
      increase: false,
      unchanged: true,
    );
  }
  final amount = formatIncomeQuantity(delta.abs());
  if (delta > 0) {
    return IncomeDeltaDisplay(
      text: '↑+$amount',
      increase: true,
      unchanged: false,
    );
  }
  return IncomeDeltaDisplay(
    text: '↓-$amount',
    increase: false,
    unchanged: false,
  );
}

/// Formats a backend timestamp (`yyyy-MM-dd HH:mm:ss`) into `HH:mm`.
String formatIncomeClock(String raw) {
  final value = DateTime.tryParse(raw.trim().replaceFirst(' ', 'T'));
  if (value == null) {
    return '';
  }
  return DateFormat('HH:mm').format(value);
}

/// Formats a day key (`yyyy-MM-dd`) into `MM-dd`.
String formatIncomeDayLabel(String dayKey) {
  final value = DateTime.tryParse(dayKey.trim());
  if (value == null) {
    return dayKey;
  }
  return DateFormat('MM-dd').format(value);
}
