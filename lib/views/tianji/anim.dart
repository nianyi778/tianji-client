/// 天机的动效基件。
///
/// 🔴 整个 app 的时长与曲线只在这里定义。散在各页各写一个 300ms 的结果是
///    每一页的手感都差一点点 —— 那正是「不够细腻」的来源。
///
/// 🔴 一律用 `addPostFrameCallback` 起动画，**不用 Timer**：Timer 在 widget
///    测试里会留下「A Timer is still pending even after the widget tree was
///    disposed」，把整棵树的测试弄红（2026-09-30 为此重写过一次 AI 状态轮询）。
library;

import 'package:flutter/material.dart';

/// 内容出现：快一点，别让人等
const tjFast = Duration(milliseconds: 180);

/// 状态切换：颜色、尺寸
const tjNormal = Duration(milliseconds: 280);

/// 强调：进度条长出来、卡片展开
const tjSlow = Duration(milliseconds: 620);

/// 减速曲线。界面元素「滑到位然后停住」用它，不要用 linear
const tjCurve = Curves.easeOutCubic;

/// 列表入场：淡入 + 上移，按序号错开。
///
/// 为什么要错开：一屏卡片同时出现会像一张静止的图片「啪」地贴上来；
/// 错开 [step] 之后眼睛能跟着读下去，这是「细腻」最便宜的一处来源。
///
/// 🔴 错开量有上限（默认封在第 8 项）：列表有几十行时，再线性错下去
///    最后一行要等两秒才出现，那不是精致是卡。
class TianjiStagger extends StatefulWidget {
  final int index;
  final Widget child;

  /// 每一项之间错开多久
  final Duration step;

  const TianjiStagger({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 45),
  });

  @override
  State<TianjiStagger> createState() => _TianjiStaggerState();
}

class _TianjiStaggerState extends State<TianjiStagger> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final delay = widget.step * widget.index.clamp(0, 8);
    final d = tjNormal + delay;
    return AnimatedSlide(
      offset: Offset(0, (1 - _t) * 0.05),
      duration: d,
      curve: tjCurve,
      child: AnimatedOpacity(
        opacity: _t,
        duration: d,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// 按下时轻微缩小。给「这是能点的」一个物理答复。
///
/// 🔴 只缩 2%：再多就像按钮在弹跳，用两次就腻了。
class TianjiTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TianjiTapScale({super.key, required this.child, this.onTap});

  @override
  State<TianjiTapScale> createState() => _TianjiTapScaleState();
}

class _TianjiTapScaleState extends State<TianjiTapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: widget.onTap == null
        ? null
        : (_) => setState(() => _down = true),
    onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
    onTapCancel: widget.onTap == null
        ? null
        : () => setState(() => _down = false),
    onTap: widget.onTap,
    child: AnimatedScale(
      scale: _down ? 0.98 : 1,
      duration: tjFast,
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}
