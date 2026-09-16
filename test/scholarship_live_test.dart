// 显式本机验收，不写入用户数据库。
import 'package:calendar/data/llm/ollama_client.dart';
import 'package:calendar/data/parsers/local_model_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    '奖学金通知：学年不影响年份、仅截止时间20:00',
    () async {
      final client = OllamaClient(const LocalModelConfig());
      await client.check();
      final parser = LocalModelParser(
        client,
        now: () => DateTime(2026, 9, 16, 12),
      );
      const input = LocalInput(
        text: '@所有人 转教务办通知： 各位23、24、25级的同学好，现学院开启【2025-2026学年奖学金评定工作】具体细则参照学院文件，请各位同学按照申请类型填报在线表格，表格下方有对应的奖项类别，其中宝钢优秀学生奖为学院推荐，学校参评；林浩然奖学金可以兼得；综合奖学金不用申报等级。请各位同学于9月19日晚8点前完成在线表格的填报【腾讯文档】2025-2026学年奖学金申报表',
      );
      for (var i = 0; i < 3; i++) {
        final results = await parser.parse(input);
        // ignore: avoid_print
        print(
          '第${i + 1}次：${results.map((e) => '${e.title}: start=${e.start}, end=${e.end}').join('; ')}',
        );
        expect(results, hasLength(1));
        expect(results.single.start, isNull);
        expect(results.single.end, DateTime(2026, 9, 19, 20));
        expect(results.single.allDay, false);
      }
    },
    skip: !const bool.fromEnvironment('RUN_LOCAL_MODEL_TESTS'),
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
