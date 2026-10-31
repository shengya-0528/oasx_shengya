part of 'api_client.dart';

/// Income (资产) endpoints served by the OAS backend income router.
extension ApiClientIncomeX on ApiClient {
  /// Fetches every date that has an income snapshot for one script.
  Future<ScriptIncomeDateList> getScriptIncomeDates(String scriptName) async {
    final path = '/income/${Uri.encodeComponent(scriptName)}/dates';
    final res = await request(() => get(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid income dates response');
    }
    return ScriptIncomeDateList.fromJson(Map<String, dynamic>.from(res.data));
  }

  /// Fetches one day income snapshot with the chosen compare baseline.
  ///
  /// [compareDays] picks the change baseline: `1` / `3` / `7` mean "compare with
  /// the day N days before", `0` keeps the backend's "last recorded day" rule.
  Future<ScriptIncomeDay> getScriptIncomeDay(
    String scriptName,
    String dateKey, {
    int compareDays = 1,
  }) async {
    final date = dateKey.trim();
    if (date.isEmpty) {
      throw Exception('Income date is required');
    }
    final compare = compareDays < 0 ? 0 : compareDays;
    final path =
        '/income/${Uri.encodeComponent(scriptName)}'
        '?date=${Uri.encodeComponent(date)}&compare=$compare';
    final res = await request(() => get(path));
    if (!res.isSuccess || res.data is! Map) {
      throw Exception(res.error ?? 'Invalid income response');
    }
    return ScriptIncomeDay.fromJson(
      Map<String, dynamic>.from(res.data),
      dateKey: date,
    );
  }
}
