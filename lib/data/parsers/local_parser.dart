/// 离线解析引擎（文档第 5 章）：纯 Dart 正则 + 词库，零网络、零第三方 NLP 依赖。
///
/// 处理管道（文档 5.1 节）：
///   原始文本 → 句子切分 → 每句执行 日期时间抽取 → 地点抽取 → 事务识别
///            → 组装 ParsedEvent（missing 标记 + 置信度）→ 全句零命中丢弃
library;

import '../../core/errors.dart';
import '../../core/regex_patterns.dart';
import '../../domain/event_source_type.dart';
import '../../domain/parsed_event.dart';
import '../../domain/word_lists.dart';
import 'event_parser.dart';

/// 时间解析结果
typedef _TimeParts = ({int hour, int minute});

class LocalParser implements EventParser {
  /// 可注入时钟便于测试（文档 15.1 节用例表）
  LocalParser({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  @override
  Future<List<ParsedEvent>> parse(String text) async {
    final now = _now();
    final events = <ParsedEvent>[];
    for (final sentence in _splitSentences(text)) {
      events.addAll(_parseSentence(sentence, now));
    }
    if (events.isEmpty) {
      throw const LocalParseException('未能从文本中识别出事件信息，请补充时间与事项后重试');
    }
    return events;
  }

  // ---------------------------------------------------------------- 句子切分

  List<String> _splitSentences(String text) {
    return text
        .split(sentenceSplit)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  // ------------------------------------------------------------ 单句解析入口

  List<ParsedEvent> _parseSentence(String text, DateTime now) {
    // 多事件切分（文档 5.5 节）：仅当关键词之间存在日期/时间信息时才分段
    // （"出差开会"这类连续关键词视为同一事件，文档 5.4 节规则 1）
    final keywords = _findKeywords(text);
    if (keywords.length >= 2) {
      final splitPoints = <int>[];
      for (var i = 0; i < keywords.length - 1; i++) {
        final gapStart = keywords[i].$1 + keywords[i].$2.length;
        final gap = text.substring(gapStart, keywords[i + 1].$1);
        if (_gapHasDateTime(gap)) splitPoints.add(i + 1);
      }
      if (splitPoints.isNotEmpty) {
        // 整句的全局日期（通常位于句首，各分段共享；分段自身日期优先）
        final sharedDate = _resolveDate(text, now);
        final result = <ParsedEvent>[];
        // 分段边界：上一段终点即下一段起点（保留下一段的日期片段）
        final cuts = <int>[keywords.first.$1];
        for (final sp in splitPoints) {
          cuts.add(_segmentEnd(text, keywords[sp].$1, keywords[sp - 1]));
        }
        cuts.add(text.length);
        for (var i = 0; i < cuts.length - 1; i++) {
          final segment = text.substring(cuts[i], cuts[i + 1]).trim();
          if (segment.isEmpty) continue;
          final e = _parseSegment(segment, now, sharedDate: sharedDate);
          if (e != null) result.add(e);
        }
        return result;
      }
    }
    final e = _parseSegment(text, now);
    return e == null ? <ParsedEvent>[] : [e];
  }

  bool _gapHasDateTime(String gap) {
    return absoluteDate.hasMatch(gap) ||
        relativeDateWord.hasMatch(gap) ||
        timeRange.hasMatch(gap) ||
        timeExpr.hasMatch(gap);
  }

  /// 分段终点：若下一关键词前存在日期/时间片段，截到该片段开始处
  /// （"周一开会，周二出差"→ 前段止于"周二"之前）
  int _segmentEnd(String text, int nextKwStart, (int, String) prevKw) {
    final gapStart = prevKw.$1 + prevKw.$2.length;
    final gap = text.substring(gapStart, nextKwStart);
    final matches = <RegExpMatch>[
      ...absoluteDate.allMatches(gap),
      ...relativeDateWord.allMatches(gap),
      ...timeRange.allMatches(gap),
      ...timeExpr.allMatches(gap),
    ]..sort((a, b) => a.start.compareTo(b.start));
    if (matches.isEmpty) return nextKwStart;
    return gapStart + matches.first.start;
  }

  /// 找到所有关键词（长度降序优先，避免"交"误吞"提交"等），返回 (位置, 关键词)
  List<(int, String)> _findKeywords(String text) {
    final result = <(int, String)>[];
    final sorted = [...kTaskKeywords]..sort((a, b) => b.length.compareTo(a.length));
    var searchFrom = 0;
    while (searchFrom < text.length) {
      (int, String)? best;
      for (final kw in sorted) {
        final idx = text.indexOf(kw, searchFrom);
        if (idx >= 0 && (best == null || idx < best.$1)) best = (idx, kw);
      }
      if (best == null) break;
      result.add(best);
      searchFrom = best.$1 + best.$2.length;
    }
    return result;
  }

  // -------------------------------------------------------------- 单段解析

  ParsedEvent? _parseSegment(
    String text,
    DateTime now, {
    DateTime? sharedDate,
  }) {
    var confidence = 0.0;

    // ---- 1. 时间（区间优先） ----
    _TimeParts? startTime;
    _TimeParts? endTime;
    final range = timeRange.firstMatch(text);
    final single = range == null ? timeExpr.firstMatch(text) : null;
    if (range != null) {
      startTime = _parseTimeParts(range, prefix: 'start');
      endTime = _parseTimeParts(range, prefix: 'end');
      // 区间省略结束时段词时继承开始时段（"下午3点到5点"→ 17:00，文档 5.2 节）
      if (startTime != null &&
          endTime != null &&
          range.namedGroup('endSlot') == null &&
          endTime.hour < 12 &&
          startTime.hour >= 12) {
        endTime = (hour: endTime.hour + 12, minute: endTime.minute);
      }
      if (startTime != null && endTime != null) confidence += 0.4;
    } else if (single != null) {
      startTime = _parseTimeParts(single, prefix: '');
      if (startTime != null) confidence += 0.4;
    }

    // ---- 2. 日期（绝对优先，其次相对；分段无日期时共享全局日期） ----
    final isAllDayWord = allDayWord.hasMatch(text);
    var date = _resolveDate(text, now);
    date ??= sharedDate;
    if (date == null && isAllDayWord) {
      // "全天"无日期 → 默认今天（文档 5.2 节缺省规则）
      date = DateTime(now.year, now.month, now.day);
    }
    if (date != null) {
      confidence += 0.4; // 有日期视为时间命中（含缺省，文档 5.6 节）
    } else if (startTime != null) {
      // 有时刻无日期：默认今天，时刻已过顺延明天（文档 5.2 节缺省规则）
      final today = DateTime(now.year, now.month, now.day);
      date = today;
      final candidate = DateTime(
        today.year,
        today.month,
        today.day,
        startTime.hour,
        startTime.minute,
      );
      if (candidate.isBefore(now)) date = today.add(const Duration(days: 1));
    }

    // 无时间信息也无关键词 → 零命中，丢弃该句
    final hasKeyword = _findKeywords(text).isNotEmpty;
    if (date == null && !hasKeyword) return null;
    if (hasKeyword) confidence += 0.3; // 事务识别命中（文档 5.6 节）

    final allDay = isAllDayWord || (date != null && startTime == null);
    DateTime? start;
    DateTime? end;
    if (date != null) {
      if (allDay) {
        start = DateTime(date.year, date.month, date.day);
      } else {
        start = DateTime(
          date.year,
          date.month,
          date.day,
          startTime!.hour,
          startTime.minute,
        );
        if (endTime != null) {
          end = DateTime(
            date.year,
            date.month,
            date.day,
            endTime.hour,
            endTime.minute,
          );
          // 跨天区间：结束 < 开始 → 加一天（文档 5.2 节）
          if (end.isBefore(start)) end = end.add(const Duration(days: 1));
        }
      }
    }

    // ---- 3. 地点 ----
    final location = _extractLocation(text, from: 0);
    if (location != null) confidence += 0.3;

    // ---- 4. 标题与备注 ----
    final (title, note) = _extractTitleAndNote(text);

    // ---- 5. 缺失标记与置信度 ----
    final missing = <MissingField>{
      if (start == null) MissingField.time,
      if (location == null) MissingField.location,
      if (title.isEmpty) MissingField.title,
    };

    return ParsedEvent(
      title: title,
      location: location,
      start: start,
      end: end,
      allDay: allDay,
      note: note,
      sourceType: EventSourceType.text,
      sourceText: text,
      missing: missing,
      confidence: confidence.clamp(0.0, 1.0),
    );
  }

  // ------------------------------------------------------------ 日期解析

  DateTime? _resolveDate(String text, DateTime now) {
    final abs = absoluteDate.firstMatch(text);
    if (abs != null) {
      final hasYear = abs.namedGroup('year') != null;
      final year = hasYear ? int.parse(abs.namedGroup('year')!) : now.year;
      final month = int.parse(abs.namedGroup('month')!);
      final day = int.parse(abs.namedGroup('day')!);
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      final dt = DateTime(year, month, day);
      // 溢出日期（如 2月30日、2026年2月29日）视为无效（闰年校验）
      if (dt.day != day || dt.month != month) return null;
      // 无年份一律取当前系统年（文档 5.2 节）；已过日期保留，由 UI"日期已过"提示兜底
      return dt;
    }

    final rel = relativeDateWord.firstMatch(text);
    if (rel != null) return _resolveRelativeDate(rel.group(0)!, now);
    // 仅提供"日"：15号/15日 → 年月取系统当前（文档 5.2 节）
    final dayOnly = dayOnlyDate.firstMatch(text);
    if (dayOnly != null) {
      final day = int.parse(dayOnly.namedGroup('day')!);
      if (day < 1 || day > 31) return null;
      final dt = DateTime(now.year, now.month, day);
      // 当月天数校验（如 4月31日 无效）
      if (dt.day != day) return null;
      return dt;
    }
    return null;
  }

  DateTime _resolveRelativeDate(String word, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    switch (word) {
      case '今天':
        return today;
      case '明天':
        return today.add(const Duration(days: 1));
      case '后天':
        return today.add(const Duration(days: 2));
      case '大后天':
        return today.add(const Duration(days: 3));
      case '昨天':
        return today.subtract(const Duration(days: 1));
      case '前天':
        return today.subtract(const Duration(days: 2));
      case '周末':
        final sat = thisWeekStart.add(const Duration(days: 5));
        return sat.isBefore(today) ? sat.add(const Duration(days: 7)) : sat;
    }
    if (word.startsWith('本周')) {
      return thisWeekStart.add(
        Duration(days: _weekdayNumber(word[word.length - 1]) - 1),
      );
    }
    if (word.startsWith('下周')) {
      return thisWeekStart.add(
        Duration(days: 7 + _weekdayNumber(word[word.length - 1]) - 1),
      );
    }
    if (word.startsWith('周')) {
      final day = thisWeekStart.add(
        Duration(days: _weekdayNumber(word[word.length - 1]) - 1),
      );
      return day.isBefore(today) ? day.add(const Duration(days: 7)) : day;
    }
    return today; // 不可达
  }

  int _weekdayNumber(String ch) {
    return switch (ch) {
      '一' => 1,
      '二' => 2,
      '三' => 3,
      '四' => 4,
      '五' => 5,
      '六' => 6,
      _ => 7, // 日 / 天
    };
  }

  // ------------------------------------------------------------ 时间解析

  _TimeParts? _parseTimeParts(RegExpMatch m, {required String prefix}) {
    // 单时间用无前缀组名，区间用 start/end 前缀组名
    final hourStr =
        prefix.isEmpty ? m.namedGroup('hour') : m.namedGroup('${prefix}Hour');
    if (hourStr == null) return null;
    var hour = int.parse(hourStr);
    var minute = 0;
    final minStr = prefix.isEmpty
        ? m.namedGroup('minute')
        : m.namedGroup('${prefix}Minute');
    if (minStr != null) {
      final t = minStr.trim();
      if (t == '半') {
        minute = 30;
      } else if (t == '一刻') {
        minute = 15;
      } else if (t == '三刻') {
        minute = 45;
      } else {
        minute = int.parse(t.replaceAll('分', '').trim());
      }
    }
    final slot = prefix.isEmpty
        ? m.namedGroup('slot')
        : m.namedGroup('${prefix}Slot');
    // 时段映射（文档 5.2 节）：下午/傍晚/晚上 + 小时<12 → +12；12 点归中午 12:00
    if (slot != null &&
        hour < 12 &&
        (slot == '下午' || slot == '傍晚' || slot == '晚上')) {
      hour += 12;
    }
    if (hour > 23 || minute > 59) return null;
    return (hour: hour, minute: minute);
  }

  // ------------------------------------------------------------ 地点抽取

  String? _extractLocation(String text, {required int from}) {
    // 策略 1：介词锚点（取最早出现的介词，从其后截取到停用词/关键词/标点）
    int? bestPrep;
    String? bestWord;
    for (final prep in kLocationPrepositions) {
      final idx = text.indexOf(prep, from);
      if (idx >= 0 && (bestPrep == null || idx < bestPrep)) {
        bestPrep = idx;
        bestWord = prep;
      }
    }
    if (bestPrep != null) {
      final start = bestPrep + bestWord!.length;
      final end = _cutIndex(text, start);
      final raw = text.substring(start, end).trim();
      final cleaned = _cleanLocation(raw);
      if (cleaned.isNotEmpty) return cleaned;
    }

    // 策略 2：后缀词表兜底（文档 5.3 节）；窗口不跨越日期/时间片段
    final sorted = [...kLocationSuffixes]
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final suffix in sorted) {
      final idx = text.indexOf(suffix, from);
      if (idx < 0) continue;
      final fragmentEnd = _lastFragmentEndBefore(text, idx);
      final start = idx - 8 < fragmentEnd ? fragmentEnd : idx - 8;
      var cut = start;
      final m = punctuation.firstMatch(text.substring(start, idx));
      if (m != null) cut = start + m.start;
      final raw = text.substring(cut, idx + suffix.length).trim();
      final cleaned = _cleanLocation(raw);
      if (cleaned.isNotEmpty) return cleaned;
    }
    return null;
  }

  /// 文本中在 [before] 之前结束的最近一个日期/时间片段末尾
  int _lastFragmentEndBefore(String text, int before) {
    var end = 0;
    for (final re in [absoluteDate, relativeDateWord, timeRange, timeExpr]) {
      for (final m in re.allMatches(text)) {
        if (m.end <= before && m.end > end) end = m.end;
      }
    }
    return end;
  }

  /// 从 [from] 起截取到第一个 标点 / 关键词（其后非中文，避免"会议室"内的"会议"） / 地点停用词 处
  int _cutIndex(String text, int from) {
    for (var i = from; i < text.length; i++) {
      if (punctuation.hasMatch(text[i])) return i;
      final slice = text.substring(from, i + 1);
      for (final kw in kTaskKeywords) {
        final kLen = kw.length;
        if (slice.endsWith(kw) && i + 1 - kLen >= from) {
          final after = i + 1 < text.length ? text[i + 1] : '';
          // 后面紧跟中文时跳过（"会议室"内的"会议"）；但若中文处是另一关键词起点
          // （"上海出差开会"）则视为有效截断点
          final afterStartsKeyword =
              after.isNotEmpty && _keywordStartsAt(text, i + 1);
          if (after.isEmpty || !_isCjk(after) || afterStartsKeyword) {
            return i + 1 - kLen;
          }
        }
      }
      for (final stop in kLocationStops) {
        if (slice.endsWith(stop)) return i + 1 - stop.length;
      }
    }
    return text.length;
  }

  bool _isCjk(String ch) {
    final code = ch.codeUnitAt(0);
    return code >= 0x4E00 && code <= 0x9FFF;
  }

  bool _keywordStartsAt(String text, int idx) {
    for (final kw in kTaskKeywords) {
      if (text.startsWith(kw, idx)) return true;
    }
    return false;
  }

  String _cleanLocation(String raw) {
    var s = raw.trim();
    // 去掉首部的 介词/连接词 与尾部的 语气/连接词
    for (final prep in kLocationPrepositions) {
      if (s.startsWith(prep)) s = s.substring(prep.length);
    }
    for (final suffix in const ['的', '了', '并', '和', '以及']) {
      if (s.endsWith(suffix)) s = s.substring(0, s.length - suffix.length);
    }
    s = s.trim();
    if (s.isEmpty) return s;
    // 地点需含至少一个后缀词或长度 >= 2（避免"去开会"等误判）
    for (final suffix in kLocationSuffixes) {
      if (s.contains(suffix)) return s;
    }
    return s.length >= 2 ? s : '';
  }

  // ------------------------------------------------------------ 标题与备注

  (String, String?) _extractTitleAndNote(String text) {
    final keywords = _findKeywords(text);
    if (keywords.isNotEmpty) {
      // 动作动词通常位于短语末尾（"会议室开会"→开会；"去上海出差"→出差），取最后关键词
      final (kwIdx, kw) = keywords.last;
      var title = kw;
      String? note;
      // 前置紧邻关键词拼接（文档 5.4 节规则 1："出差开会"→"出差开会"）
      if (keywords.length >= 2) {
        final (prevIdx, prevKw) = keywords[keywords.length - 2];
        final between = text.substring(prevIdx + prevKw.length, kwIdx);
        if (RegExp(r'^[，,。；;\s]*$').hasMatch(between)) {
          title = prevKw + kw;
        }
      }
      var rest = text.substring(kwIdx + kw.length);
      rest = rest.replaceFirst(RegExp(r'^[，,。；;\s]+'), '');
      if (rest.isNotEmpty) {
        final trimmed = rest.trim();
        final isConnector = kNoteConnectors.any(trimmed.startsWith);
        if (isConnector) {
          // 连接词开头 → 转入备注（文档 5.4 节规则 2）
          note = _trimNote(trimmed);
        } else if (title.length < 8) {
          // 动宾短语扩展（"交房租"），上限 8 字（文档 5.4 节规则 1）
          final take = 8 - title.length;
          final phrase = trimmed.length > take
              ? trimmed.substring(0, take)
              : trimmed;
          title = title + phrase;
        }
      }
      return (title, note);
    }

    // 无关键词：去掉日期/时间/地点片段后取主干（≤20 字，文档 5.4 节规则 3）
    final removed = _stripFragments(text);
    final cleaned = removed.replaceFirst(
      RegExp(r'^[去到达在前往飞往请记得，。；\s]+'),
      '',
    );
    final title = cleaned.length > 20 ? cleaned.substring(0, 20) : cleaned;
    return (title.trim(), null);
  }

  String? _trimNote(String s) {
    final t = s.replaceFirst(RegExp(r'^[，,。；;\s]+'), '');
    if (t.isEmpty) return null;
    return t.length > 50 ? t.substring(0, 50) : t;
  }

  /// 移除文本中的日期/时间/地点片段，用于无关键词时的标题主干
  String _stripFragments(String text) {
    final ranges = <({int start, int end})>[];
    final date = absoluteDate.firstMatch(text);
    if (date != null) ranges.add((start: date.start, end: date.end));
    final rel = relativeDateWord.firstMatch(text);
    if (rel != null) ranges.add((start: rel.start, end: rel.end));
    final dayOnly = dayOnlyDate.firstMatch(text);
    if (dayOnly != null) ranges.add((start: dayOnly.start, end: dayOnly.end));
    final range = timeRange.firstMatch(text);
    if (range != null) {
      ranges.add((start: range.start, end: range.end));
    } else {
      final single = timeExpr.firstMatch(text);
      if (single != null) ranges.add((start: single.start, end: single.end));
    }
    final location = _extractLocation(text, from: 0);
    if (location != null) {
      final idx = text.indexOf(location);
      if (idx >= 0) ranges.add((start: idx, end: idx + location.length));
    }

    final sb = StringBuffer();
    var cursor = 0;
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    for (final r in sorted) {
      if (r.start < cursor) continue;
      sb.write(text.substring(cursor, r.start));
      cursor = r.end;
    }
    sb.write(text.substring(cursor));
    return sb.toString();
  }
}
