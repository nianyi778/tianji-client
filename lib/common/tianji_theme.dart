/// 天机的设计系统 —— 颜色、圆角、间距、字号的**唯一出处**。
///
/// 🔴 为什么要有这一层：上游的主题从一个种子色派生全部颜色，默认种子是
///    `0xFFD8C0C3`（藕粉），于是整个 app 怎么改都不像我们的产品。而页面里又各自
///    写着 `Color(0xFF34C759)` 这类字面量，改一次配色要翻遍所有文件。
///    这里把令牌集中定义，页面只引用语义名（`tj.good` / `tj.card`），不碰色值。
///
/// 🔴 与官网同一套色：底 #FFFFFF / 卡片 #F5F5F7 / 主色 #0071E3，
///    暗色 #0B0B0C / #161618 / #2997FF。客户从落地页点进 app 不该觉得换了个产品。
///
/// 状态色（绿/黄/红）**独立于主色**，不参与品牌色的派生 —— 它表达的是
/// 「能用 / 有风险 / 不可用」，换品牌色时它不该跟着变。
library;

import 'package:flutter/material.dart';

// ── 品牌色 ────────────────────────────────────────────────────────────
const tianjiBlue = Color(0xFF0071E3);
const tianjiBlueDark = Color(0xFF2997FF);

// ── 圆角 ──────────────────────────────────────────────────────────────
/// 卡片与大块容器
const tjRadiusCard = 14.0;

/// 按钮、输入框、列表项
const tjRadiusControl = 12.0;

/// 胶囊（当前线路那一行）
const tjRadiusPill = 999.0;

// ── 间距梯度。页面里只用这几个值，不要随手写 13、17。 ──────────────────
const tjGap1 = 4.0;
const tjGap2 = 8.0;
const tjGap3 = 12.0;
const tjGap4 = 16.0;
const tjGap5 = 24.0;
const tjGap6 = 32.0;

/// 语义颜色。挂在 ThemeExtension 上，页面用 `context.tj.good` 取，
/// 不再在各处写死色值。
@immutable
class TianjiColors extends ThemeExtension<TianjiColors> {
  /// 能用 / 正常
  final Color good;

  /// 有风险 / 需要注意
  final Color warn;

  /// 不可用
  final Color bad;

  /// 测不出结论 —— 🔴 它必须和 bad 明显不同：把「没测出来」画成红色
  /// 等于把自己的探测失败报成线路故障。
  final Color unknown;

  /// 卡片底
  final Color card;

  /// 页面底
  final Color ground;

  /// 次级文字
  final Color ink2;

  /// 更弱的文字与图标
  final Color ink3;

  /// 分隔线
  final Color line;

  const TianjiColors({
    required this.good,
    required this.warn,
    required this.bad,
    required this.unknown,
    required this.card,
    required this.ground,
    required this.ink2,
    required this.ink3,
    required this.line,
  });

  static const light = TianjiColors(
    good: Color(0xFF1F9D55),
    warn: Color(0xFFB26B00),
    bad: Color(0xFFD70015),
    unknown: Color(0xFF9A9AA0),
    card: Color(0xFFF5F5F7),
    ground: Color(0xFFFFFFFF),
    ink2: Color(0xFF5D5D63),
    ink3: Color(0xFF8A8A91),
    line: Color(0x1F000000),
  );

  static const dark = TianjiColors(
    good: Color(0xFF34C759),
    warn: Color(0xFFFF9F0A),
    bad: Color(0xFFFF453A),
    unknown: Color(0xFF6E6E76),
    card: Color(0xFF161618),
    ground: Color(0xFF0B0B0C),
    ink2: Color(0xFFA8A8AE),
    ink3: Color(0xFF6E6E76),
    line: Color(0x24FFFFFF),
  );

  @override
  TianjiColors copyWith({
    Color? good,
    Color? warn,
    Color? bad,
    Color? unknown,
    Color? card,
    Color? ground,
    Color? ink2,
    Color? ink3,
    Color? line,
  }) => TianjiColors(
    good: good ?? this.good,
    warn: warn ?? this.warn,
    bad: bad ?? this.bad,
    unknown: unknown ?? this.unknown,
    card: card ?? this.card,
    ground: ground ?? this.ground,
    ink2: ink2 ?? this.ink2,
    ink3: ink3 ?? this.ink3,
    line: line ?? this.line,
  );

  @override
  TianjiColors lerp(ThemeExtension<TianjiColors>? other, double t) {
    if (other is! TianjiColors) return this;
    return TianjiColors(
      good: Color.lerp(good, other.good, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      bad: Color.lerp(bad, other.bad, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
      card: Color.lerp(card, other.card, t)!,
      ground: Color.lerp(ground, other.ground, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

extension TianjiThemeContext on BuildContext {
  TianjiColors get tj =>
      Theme.of(this).extension<TianjiColors>() ?? TianjiColors.light;
}

/// 把天机的形状、字距、组件默认值叠加到上游给出的 [base] 上。
///
/// 🔴 只改**视觉默认值**，不换 ColorScheme —— 配色仍由上游那套（种子色 + 用户可选
///    的主色）产生，这样用户在设置里换主色仍然有效，我们只是把默认种子换成了品牌蓝。
ThemeData tianjiTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final tj = dark ? TianjiColors.dark : TianjiColors.light;
  final cs = base.colorScheme;

  RoundedRectangleBorder r(double v) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(v));

  return base.copyWith(
    extensions: [tj],
    scaffoldBackgroundColor: tj.ground,
    dividerColor: tj.line,
    // 🔴 Material 默认给中文正文的字距是给拉丁字母调的，中文会显得松散发虚。
    //    这里收紧字距、压实行高，长句读起来才不散。
    textTheme: base.textTheme
        .apply(
          fontFamilyFallback: const [
            'PingFang SC',
            'Hiragino Sans GB',
            'Noto Sans CJK SC',
          ],
        )
        .copyWith(
          headlineMedium: base.textTheme.headlineMedium?.copyWith(
            letterSpacing: -0.5,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: base.textTheme.titleLarge?.copyWith(
            letterSpacing: -0.3,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            letterSpacing: -0.1,
          ),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
          bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.45),
        ),
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      color: tj.card,
      shape: r(tjRadiusCard),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: tj.line,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: base.listTileTheme.copyWith(
      shape: r(tjRadiusControl),
      iconColor: tj.ink2,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: r(tjRadiusControl),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        // 🔴 必须从 base.textTheme 派生，不能写一个裸的 TextStyle ——
        //    裸的没有 fontFamily / fontFamilyFallback，按钮文字就不跟随
        //    上面那套 CJK 字体栈了。中文环境下多数平台有系统兜底看不出来，
        //    一旦用户在设置里换字体、或在缺兜底的环境里，按钮文字直接变方框。
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: r(tjRadiusControl),
        side: BorderSide(color: tj.line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: r(tjRadiusControl)),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tjRadiusControl),
        borderSide: BorderSide(color: tj.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tjRadiusControl),
        borderSide: BorderSide(color: tj.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tjRadiusControl),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    dialogTheme: base.dialogTheme.copyWith(shape: r(tjRadiusCard + 4)),
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    snackBarTheme: base.snackBarTheme.copyWith(
      behavior: SnackBarBehavior.floating,
      shape: r(tjRadiusControl),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: tj.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
          color: s.contains(WidgetState.selected) ? cs.primary : tj.ink3,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? cs.primary : tj.ink3,
        ),
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: tj.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
    ),
  );
}

/// 品牌山影。侧栏底部与首页连接卡共用同一条折线 —— 它是品牌图形的一部分，
/// 两处各画一份会慢慢长歪。纯装饰，用 Canvas 画，不引图片资源。
class TianjiRidgePainter extends CustomPainter {
  /// 山影的颜色（自带透明度）。深色侧栏给白，浅色卡片给品牌蓝。
  final Color color;

  const TianjiRidgePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    void ridge(double top, double alpha, List<double> peaks) {
      final p = Path()..moveTo(0, size.height);
      final step = size.width / (peaks.length - 1);
      p.lineTo(0, size.height - top * peaks.first);
      for (var i = 1; i < peaks.length; i++) {
        final x = step * i;
        final prevX = step * (i - 1);
        final y = size.height - top * peaks[i];
        final prevY = size.height - top * peaks[i - 1];
        p.cubicTo(prevX + step * 0.4, prevY, x - step * 0.4, y, x, y);
      }
      p
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        p,
        Paint()..color = color.withValues(alpha: color.a * alpha),
      );
    }

    ridge(size.height * 0.55, 0.75, [0.35, 0.75, 0.45, 0.9, 0.5, 0.7]);
    ridge(size.height * 0.34, 1.0, [0.6, 0.3, 0.85, 0.4, 0.75, 0.35]);
  }

  @override
  bool shouldRepaint(covariant TianjiRidgePainter old) => old.color != color;
}
