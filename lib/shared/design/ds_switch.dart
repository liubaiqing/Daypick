/// macOS 风格开关（文档 9.6 节 DSSwitch）：全天/动画开关等布尔项。
library;

import 'package:flutter/material.dart';

import 'ds_tokens.dart';
import 'dstokens_scope.dart';

class DSSwitch extends StatelessWidget {
  const DSSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.activeColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  /// 覆盖开启态颜色（如设置窗口在毛玻璃主题下用柔和绿）
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final tokens = DSTokensScope.of(context);
    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: AnimatedContainer(
        duration: kDurationQuick,
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value
              ? activeColor ?? tokens.successGreen
              : tokens.textSecondary.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedAlign(
          duration: kDurationQuick,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
