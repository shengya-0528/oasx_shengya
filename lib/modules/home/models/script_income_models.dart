/// One resource row returned by `/income/{script_name}?date=`.
class ScriptIncomeItem {
  /// Creates one income row.
  ScriptIncomeItem({
    required this.name,
    required this.value,
    this.delta,
    this.first,
    this.deltaFirst,
  });

  /// Builds one row from the backend payload.
  factory ScriptIncomeItem.fromJson(Map<String, dynamic> json) {
    return ScriptIncomeItem(
      name: _readString(json['name']),
      value: _readIntOrNull(json['value']) ?? -1,
      delta: _readIntOrNull(json['delta']),
      first: _readIntOrNull(json['first']),
      deltaFirst: _readIntOrNull(json['delta_first']),
    );
  }

  /// Backend field name such as `gold`; the panel owns its localized label.
  final String name;

  /// Resource amount, `-1` when the screenshot could not be read.
  final int value;

  /// Change against the previous recorded day, null when there is none.
  final int? delta;

  /// Amount read by the first snapshot of the same day, null for old rows.
  final int? first;

  /// Change against the first snapshot of the same day, null when absent.
  final int? deltaFirst;

  /// Whether the amount was actually read out.
  bool get hasValue => value >= 0;
}

/// One day income snapshot together with the day's first read.
class ScriptIncomeDay {
  /// Creates one day snapshot.
  ScriptIncomeDay({
    required this.scriptName,
    required this.dateKey,
    required this.collectedAt,
    required this.firstReadAt,
    required this.baselineDate,
    required this.items,
  });

  /// Builds a day snapshot from the backend payload.
  factory ScriptIncomeDay.fromJson(
    Map<String, dynamic> json, {
    String dateKey = '',
  }) {
    final rawItems = json['items'];
    final items = <ScriptIncomeItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          items.add(ScriptIncomeItem.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }
    final backendDate = _readString(json['date']);
    return ScriptIncomeDay(
      scriptName: _readString(json['script_name']),
      dateKey: backendDate.isEmpty ? dateKey : backendDate,
      collectedAt: _readString(json['collected_at']),
      firstReadAt: _readString(json['first_dt']),
      baselineDate: _readString(json['baseline_date']),
      items: items,
    );
  }

  /// Script the snapshot belongs to.
  final String scriptName;

  /// Day key such as `2026-10-17`.
  final String dateKey;

  /// Time of the last read of the day, empty when the log had no timestamp.
  final String collectedAt;

  /// Time of the day's first read, empty when the day has no first read.
  final String firstReadAt;

  /// Day used by [ScriptIncomeItem.delta], empty when nothing to compare.
  final String baselineDate;

  /// Rows in backend order.
  final List<ScriptIncomeItem> items;

  /// Whether the day recorded a first read.
  ///
  /// Rows written before the first-read feature only carry their own values,
  /// so the panel has to hide the `较首读` header for them instead of
  /// showing a fake baseline.
  bool get hasFirstRead => firstReadAt.trim().isNotEmpty;

  /// Resolves one row by its backend field name.
  ScriptIncomeItem? itemFor(String name) {
    for (final item in items) {
      if (item.name == name) {
        return item;
      }
    }
    return null;
  }
}

/// Every date that has an income snapshot for one script.
class ScriptIncomeDateList {
  /// Creates one date list.
  ScriptIncomeDateList({required this.scriptName, required this.dates});

  /// Builds the date list from the backend payload.
  factory ScriptIncomeDateList.fromJson(Map<String, dynamic> json) {
    final rawDates = json['dates'];
    final dates = <String>[];
    if (rawDates is List) {
      for (final raw in rawDates) {
        final value = _readString(raw);
        if (value.isNotEmpty) {
          dates.add(value);
        }
      }
    }
    return ScriptIncomeDateList(
      scriptName: _readString(json['script_name']),
      dates: dates,
    );
  }

  /// Script the dates belong to.
  final String scriptName;

  /// Newest-first day keys.
  final List<String> dates;
}

/// Reads a trimmed string, tolerating null backend values.
String _readString(dynamic value) => value?.toString().trim() ?? '';

/// Reads an integer, tolerating numeric strings.
int? _readIntOrNull(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return int.tryParse(text) ?? double.tryParse(text)?.toInt();
}
