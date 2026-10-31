import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chinese_font_library/chinese_font_library.dart';

const List<String> _webChineseFontFallback = <String>[
  'PingFang SC',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  'Noto Sans SC',
  'Noto Sans CJK SC',
  'Source Han Sans SC',
  'WenQuanYi Micro Hei',
  'sans-serif',
];

/// 桌面端中文回退链。Windows 在前，其它平台的名字排在后面当兜底。
const List<String> _desktopChineseFontFallback = <String>[
  'Microsoft YaHei',
  'Microsoft JhengHei',
  'SimHei',
  'SimSun',
  'Noto Sans SC',
  'Noto Sans CJK SC',
  'Source Han Sans SC',
  'PingFang SC',
  'Hiragino Sans GB',
  'WenQuanYi Micro Hei',
];

/// 用枚举太麻烦了
enum ColorSeed {
  baseColor('M3 Baseline', Color(0xff6750a4)),
  indigo('Indigo', Colors.indigo),
  blue('Blue', Colors.blue),
  teal('Teal', Colors.teal),
  green('Green', Colors.green),
  yellow('Yellow', Colors.yellow),
  orange('Orange', Colors.orange),
  deepOrange('Deep Orange', Colors.deepOrange),
  pink('Pink', Colors.pink);

  const ColorSeed(this.label, this.color);
  final String label;
  final Color color;
}

const Map<String, Color> colorSeedMap = {
  'M3 Baseline': Color(0xff6750a4),
  'Indigo': Colors.indigo,
  'Blue': Colors.blue,
  'Teal': Colors.teal,
  'Green': Colors.green,
  'Yellow': Colors.yellow,
  'Orange': Colors.orange,
  'Deep Orange': Colors.deepOrange,
  'Pink': Colors.pink
};

ThemeData lightTheme = ThemeData(
  colorSchemeSeed: ColorSeed.baseColor.color,
  useMaterial3: true,
  brightness: Brightness.light,
  textTheme: _buildTextTheme(Brightness.light),
  scaffoldBackgroundColor: const Color.fromRGBO(255, 251, 255, 1),
  navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color.fromRGBO(255, 251, 255, 1)),
);

ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: ColorSeed.baseColor.color,
  brightness: Brightness.dark,
  textTheme: _buildTextTheme(Brightness.dark),
  scaffoldBackgroundColor: const Color.fromRGBO(49, 48, 51, 1),
  navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color.fromRGBO(49, 48, 51, 1)),
);

TextTheme _buildTextTheme(Brightness brightness) {
  const baseTheme = TextTheme(
    bodyLarge: TextStyle(),
    bodyMedium: TextStyle(),
    bodySmall: TextStyle(),
    labelLarge: TextStyle(),
    labelMedium: TextStyle(),
    labelSmall: TextStyle(),
    titleLarge: TextStyle(),
    titleMedium: TextStyle(),
    titleSmall: TextStyle(),
  );
  if (kIsWeb) {
    return _applyFontFallback(baseTheme, _webChineseFontFallback);
  }
  return _applyFontFallback(
    baseTheme.apply(fontFamily: 'LatoLato').useSystemChineseFont(brightness),
    _desktopChineseFontFallback,
  );
}

TextTheme _applyFontFallback(TextTheme textTheme, List<String> fallback) {
  return textTheme.copyWith(
    displayLarge: _applyTextStyleFallback(textTheme.displayLarge, fallback),
    displayMedium: _applyTextStyleFallback(textTheme.displayMedium, fallback),
    displaySmall: _applyTextStyleFallback(textTheme.displaySmall, fallback),
    headlineLarge: _applyTextStyleFallback(textTheme.headlineLarge, fallback),
    headlineMedium: _applyTextStyleFallback(textTheme.headlineMedium, fallback),
    headlineSmall: _applyTextStyleFallback(textTheme.headlineSmall, fallback),
    bodyLarge: _applyTextStyleFallback(textTheme.bodyLarge, fallback),
    bodyMedium: _applyTextStyleFallback(textTheme.bodyMedium, fallback),
    bodySmall: _applyTextStyleFallback(textTheme.bodySmall, fallback),
    labelLarge: _applyTextStyleFallback(textTheme.labelLarge, fallback),
    labelMedium: _applyTextStyleFallback(textTheme.labelMedium, fallback),
    labelSmall: _applyTextStyleFallback(textTheme.labelSmall, fallback),
    titleLarge: _applyTextStyleFallback(textTheme.titleLarge, fallback),
    titleMedium: _applyTextStyleFallback(textTheme.titleMedium, fallback),
    titleSmall: _applyTextStyleFallback(textTheme.titleSmall, fallback),
  );
}

TextStyle? _applyTextStyleFallback(TextStyle? style, List<String> fallback) {
  if (style == null) {
    return null;
  }
  // 放在最前面，而不是替换：chinese_font_library 给的链路开头是
  // "system-font"（桌面上从未 load 成功）和 "sans-serif"（桌面解析成纯
  // 拉丁字体），中文落到它们眼里就变成 .notdef 方框问号——2026-10-31
  // 金币妖怪配置页「御魂装配分组设置」下面的说明文字就是这样坏的。
  final existing = style.fontFamilyFallback ?? const <String>[];
  return style.copyWith(
    fontFamilyFallback: <String>[
      ...fallback,
      ...existing.where((family) => !fallback.contains(family)),
    ],
  );
}
