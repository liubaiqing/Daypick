// OCR 结果合并/排序后处理单元测试：
// 检测模型会把同一逻辑行拆成多个检测框，需按阅读顺序排序并同行合并。
import 'package:calendar/data/ocr/ocr_service.dart';
import 'package:flutter_onnx_ocr/flutter_onnx_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

OcrResult _box(String text, double x, double y, {double w = 100, double h = 30}) {
  return OcrResult(
    text: text,
    confidence: 0.9,
    box: [
      Offset(x, y),
      Offset(x + w, y),
      Offset(x + w, y + h),
      Offset(x, y + h),
    ],
  );
}

void main() {
  test('同一行相邻框合并为完整文本（中文直接拼接）', () {
    final results = mergeOcrResults([
      _box('上午10:00，在朴诚书院A栋1楼活', 200, 10),
      _box('动室召开新生接待工作培训会。', 500, 12),
    ]);
    expect(results, hasLength(1));
    expect(
      results.first.text,
      '上午10:00，在朴诚书院A栋1楼活动室召开新生接待工作培训会。',
    );
  });

  test('不同行不合并，且按阅读顺序（上→下）排序', () {
    final results = mergeOcrResults([
      _box('第二行文本', 50, 100),
      _box('第一行文本', 50, 10),
    ]);
    expect(results, hasLength(2));
    expect(results[0].text, '第一行文本');
    expect(results[1].text, '第二行文本');
  });

  test('同一行内乱序框按 x 排序合并', () {
    final results = mergeOcrResults([
      _box('后段', 300, 10),
      _box('前段', 100, 12),
    ]);
    expect(results, hasLength(1));
    expect(results.first.text, '前段后段');
  });

  test('ASCII 相邻框之间补空格', () {
    final results = mergeOcrResults([
      _box('hello', 0, 0),
      _box('world', 100, 0),
    ]);
    expect(results.first.text, 'hello world');
  });

  test('中英文交界不加多余空格', () {
    final results = mergeOcrResults([
      _box('【通知2】关于朴诚书院', 0, 0),
      _box('2026级', 200, 0),
    ]);
    expect(results.first.text, '【通知2】关于朴诚书院2026级');
  });

  group('折行合并（排版换行恢复完整句）', () {
    // 构造长行（宽高比 ≥ 10）：行高 30，宽 450；各行 y 递增避免被同行合并
    OcrResult longLine(String text, double y) =>
        _box(text, 0, y, w: 450, h: 30);

    test('长行非句末标点 → 与下一行拼接（可递归）', () {
      final results = mergeOcrResults([
        longLine('兹定于8月30日(周日)上', 0),
        longLine('午10:00，在朴诚书院A栋1楼活', 60),
        longLine('动室召开新生接待工作培训会。', 120),
      ]);
      expect(results, hasLength(1));
      expect(
        results.first.text,
        '兹定于8月30日(周日)上午10:00，在朴诚书院A栋1楼活动室召开新生接待工作培训会。',
      );
    });

    test('短行（宽高比不足）不参与折行合并', () {
      final results = mergeOcrResults([
        _box('团委周新淋', 0, 0, w: 150, h: 30), // 宽高比 5
        longLine('兹定于8月30日(周日)上', 60),
      ]);
      expect(results, hasLength(2));
      expect(results[0].text, '团委周新淋');
    });

    test('句末标点结尾的长行不合并', () {
      final results = mergeOcrResults([
        longLine('各位党员先锋岗成员：', 0),
        longLine('兹定于8月30日(周日)上', 60),
      ]);
      expect(results, hasLength(2));
    });

    test('合并后变短行则停止链式合并（标题行边界）', () {
      final results = mergeOcrResults([
        longLine('新生接待工作党员先锋岗的培训', 0),
        _box('通知', 0, 60, w: 60, h: 30), // 短行
        longLine('各位党员先锋岗成员：', 120),
      ]);
      // 长行"培训"被折行 → 与"通知"合并成完整标题；"通知"为短行不再链式合并，
      // 下一段落"各位党员先锋岗成员："保持独立
      expect(results, hasLength(2));
      expect(results[0].text, '新生接待工作党员先锋岗的培训通知');
      expect(results[1].text, '各位党员先锋岗成员：');
    });
  });
}
