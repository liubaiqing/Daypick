import '../data/db/database.dart';

/// 历史 start 列保留为日历排序/归属锚点，不把无开始时间的00:00显示为真实开始。
extension EventTime on Event {
  DateTime? get actualStart => allDay || !hasStartTime ? null : start;
  DateTime get orderingTime => actualStart ?? end ?? start;
  String get timeLabel {
    if (allDay) return '全天';
    String time(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (!hasStartTime) return end == null ? '全天' : '截止 ${time(end!)}';
    if (end == null) return time(start);
    final date =
        end!.year != start.year ||
            end!.month != start.month ||
            end!.day != start.day
        ? '${end!.month}/${end!.day} '
        : '';
    return '${time(start)} – $date${time(end!)}';
  }
}
