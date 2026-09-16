/// 表单时刻输入：24小时制，点号是时分分隔符，不是小数小时。
class ClockInput {
  const ClockInput(this.hour, this.minute);
  final int hour;
  final int minute;
  String get formatted =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  DateTime on(DateTime date) =>
      DateTime(date.year, date.month, date.day, hour, minute);

  static ClockInput? parse(String input) {
    var text = input.trim().replaceAll('：', ':').replaceAll('．', '.');
    text = text.replaceAllMapped(
      RegExp('[０-９]'),
      (m) => '${m[0]!.codeUnitAt(0) - 0xff10}',
    );
    text = text.replaceAll(RegExp(r'(?<=[点时])整$'), '');
    final match = RegExp(
      r'^(\d{1,2})(?:(?:[:.](\d{1,2}))|(?:[点时](?:(\d{1,2})分?)?))?$',
    ).firstMatch(text);
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2] ?? match[3] ?? '0');
    if (hour > 23 || minute > 59) return null;
    return ClockInput(hour, minute);
  }
}
