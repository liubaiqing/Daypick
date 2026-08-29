/// 离线解析正则库（文档附录 B）：所有正则只允许在此定义，禁止散落各处。
library;

/// 绝对日期：2025年3月12日 / 2025-03-12 / 2025/3/12 / 3月12日 / 3-12
final RegExp absoluteDate = RegExp(
  r'(?:(?<year>\d{4})\s*[年/-])?\s*(?<month>\d{1,2})\s*[月/-]\s*(?<day>\d{1,2})\s*日?',
);

/// 相对日期词（文档 5.2 节）
final RegExp relativeDateWord = RegExp(
  r'(今天|明天|后天|大后天|昨天|前天|本周[一二三四五六日天]|下周[一二三四五六日天]|周[一二三四五六日天]|周末)',
);

/// 时间：时段词 + 数字 + 点/时 + 半/一刻/三刻/数字分
/// 如：下午3点半 / 15:30 / 晚上8点20分 / 上午9点
final RegExp timeExpr = RegExp(
  r'(?<slot>凌晨|早上|上午|中午|下午|傍晚|晚上)?\s*'
  r'(?<hour>\d{1,2})\s*[点时:：]\s*(?<minute>半|一刻|三刻|\d{1,2}\s*分?)?',
);

/// 时间区间：X点到Y点 / X:00-Y:30 / 9时至10时（文档 5.2 节）
final RegExp timeRange = RegExp(
  r'(?<startSlot>凌晨|早上|上午|中午|下午|傍晚|晚上)?\s*(?<startHour>\d{1,2})\s*[点时:：]\s*(?<startMinute>半|一刻|三刻|\d{1,2}\s*分?)?\s*[到至\-~～]\s*'
  r'(?<endSlot>凌晨|早上|上午|中午|下午|傍晚|晚上)?\s*(?<endHour>\d{1,2})\s*[点时:：]\s*(?<endMinute>半|一刻|三刻|\d{1,2}\s*分?)?',
);

/// 全天提示词
final RegExp allDayWord = RegExp(r'全天');

/// 句子切分（文档 5.1 节）：换行 / 分号 / 句号 / 感叹号 / 问号
final RegExp sentenceSplit = RegExp(r'[\n;；。！!？?]+');

/// 中文标点（标题/备注/地点截断用）
final RegExp punctuation = RegExp(r'[，,。；;\n]');
