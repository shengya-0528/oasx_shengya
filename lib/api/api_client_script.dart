part of 'api_client.dart';

extension ApiClientScriptX on ApiClient {
  /// Loads the full argument model for one task.
  Future<Map<String, dynamic>> getScriptTask(
    String scriptName,
    String taskName, {
    bool fresh = false,
  }) async {
    final res = await request(
      () => get(
        '/${Uri.encodeComponent(scriptName)}/${Uri.encodeComponent(taskName)}/args',
        options: fresh ? _noCacheOptions() : null,
      ),
    );
    return res.data ?? {};
  }

  /// Persists one task argument through the generic value endpoint.
  Future<bool> putScriptArg(
    String scriptName,
    String taskName,
    String groupName,
    String argumentName,
    String type,
    dynamic value,
  ) async {
    final encodedValue = type == 'multi_enum' ? jsonEncode(value) : value;
    final res = await request(
      () => put(
        '/$scriptName/$taskName/$groupName/$argumentName/value',
        queryParameters: {'types': type, 'value': encodedValue},
      ),
    );
    return res.isSuccess && res.data == true;
  }

  /// Synchronizes one task back into the waiting queue immediately.
  Future<bool> syncScriptTaskNextRun(
    String scriptName,
    String taskName,
    String targetDt,
  ) async {
    final res = await request(
      () => put(
        '/$scriptName/$taskName/sync_next_run',
        queryParameters: {'target_dt': targetDt},
      ),
    );
    return res.isSuccess && res.data == true;
  }

  /// 让支持的任务下一次运行跳过「今天已经做过」的限制。
  ///
  /// 资产页的「立即读取一次」用它；任务列表的闪电 / 全部立即执行不走这里，
  /// 所以那两条入口仍然保持每天只读一次。
  Future<bool> forceScriptTaskRead(String scriptName, String taskName) async {
    final res = await request(
      () => put(
        '/${Uri.encodeComponent(scriptName)}/${Uri.encodeComponent(taskName)}/force_read',
      ),
    );
    return res.isSuccess && res.data == true;
  }
}
