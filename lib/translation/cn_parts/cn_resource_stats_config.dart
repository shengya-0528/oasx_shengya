// ignore_for_file: non_constant_identifier_names
part of i18n;

/// 资源统计（ResourceStats）与每日收益快照的字段名。
///
/// 后端 `module/log_income.py` 的 `INCOME_FIELDS` 是唯一顺序来源，
/// 这里只为 16 项各配一个中文名，不改动读取逻辑。
final Map<String, String> _cn_resource_stats_config = {
  I18n.resourceStats: '资源统计',
  'resource_stats_config': '资源统计配置',
  'method': '统计方式',
  'stat_method_help':
      '内存读取＝注入只读探针直读游戏内存，16 项全准；界面识别＝截图 OCR，只读金币/勾玉/体力/神秘符咒 4 项，且金币会被界面截成「10万」。',
  'daily_only': '每天只跑一次',
  'stat_daily_only_help': '按日期判重，同一天第二次进入直接跳过。',
  'auto_adb_root': '自动 adb root',
  'stat_auto_adb_root_help':
      '关闭时要求 adb 已经是 root，否则任务直接判失败；打开会在读取前执行 adb root。',
  'snapshot': '收益快照',
  'last_date': '上次统计日期',
  I18n.incomeGold: '金币',
  I18n.incomeJade: '勾玉',
  I18n.incomeAp: '体力',
  I18n.incomeAutoPoint: '樱饼',
  I18n.incomeHonor: '荣誉',
  I18n.incomeMedal: '勋章',
  I18n.incomeContrib: '功勋',
  I18n.incomeBrokenAmulet: '破碎的符咒',
  I18n.incomeMysteryAmulet: '神秘的符咒',
  I18n.incomeScaOrochiScales: '八岐大蛇鳞片',
  I18n.incomeScaReverseScale: '大蛇的逆鳞',
  I18n.incomeScaDemonSouls: '逢魔之魂',
  I18n.incomeHyakkiTicket: '百鬼夜行门票',
  I18n.incomeDaruma: '御行达摩',
  I18n.incomeDarumaShard: '御行达摩碎片',
  I18n.incomeQiyi: '契忆',
};
