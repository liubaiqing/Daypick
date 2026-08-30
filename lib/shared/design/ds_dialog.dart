/// macOS 风格居中弹层（文档 9.6 节 DSDialog）：遮罩 + 缩放淡入。
/// 容器走 DSGlassSurface：毛玻璃主题下玻璃质感，深色主题下无投影（§9.4.1）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/providers.dart';
import 'ds_glass_surface.dart';
import 'ds_tokens.dart';
import 'dstokens_scope.dart';

/// 展示居中弹层；[actions] 放在右下（次要 + 主要）。
Future<T?> showDSDialog<T>(
  BuildContext context, {
  required String title,
  required Widget content,
  required List<Widget> actions,
}) {
  // 动画开关：关闭时过渡瞬间完成
  final animOn = ProviderScope.containerOf(context, listen: false)
          .read(animationsEnabledProvider)
          .value ??
      true;
  final transition = animOn ? kDurationQuick : Duration.zero;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dialog',
    barrierColor: Colors.black.withValues(alpha: 0.32),
    transitionDuration: transition,
    pageBuilder: (context, _, _) {
      final tokens = DSTokensScope.of(context);
      return Center(
        child: DSGlassSurface(
          width: 420,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: kFontSizeTitle,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(child: content),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        actions[i],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
        ),
        child: child,
      ),
    ),
  );
}
