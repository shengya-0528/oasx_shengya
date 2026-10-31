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

  /// Fetches one day income snapshot together with the day's first read.
  Future<ScriptIncomeDay> getScriptIncomeDay(
    String scriptName,
    String dateKey,
  ) async {
    final date = dateKey.trim();
    if (date.isEmpty) {
      throw Exception('Income date is required');
    }
    final path =
        '/income/${Uri.encodeComponent(scriptName)}?date=${Uri.encodeComponent(date)}';
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
