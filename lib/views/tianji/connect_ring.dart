import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 手机首页的大圆环 —— 设计稿里的主角。
///
/// 一个控件同时是**状态显示**和**唯一的操作**：环的颜色说明连没连，环里写着
/// 当前延迟，点一下开关。设计稿把它放在首屏正中，因为客户开 app 十次有九次
/// 只做这一件事。
///
/// 🔴 环内的延迟是**内核实测**的那条当前线路的值，不是任何推算。测不出就显示
///    「—」而不是 0 ms —— 把「没测出来」显示成一个好看的数字，是这一页最容易
///    犯也最难发现的错（红线 6）。
///
/// 🔴 未连接用中性灰而**不用红**：「没连」不是故障。红色会让客户以为线路坏了
///    然后来开工单（红线 4 同理）。
///
/// 动画分三层，都从**同一个** [AnimationController] 驱动，避免各转各的：
///   · 呼吸光晕 —— 连接时缓慢明暗，让「在工作」这件事不必用文字说
///   · 按下缩放 —— 指下去 0.96，松开回弹，给一个物理感
///   · 状态渐变 —— 连/断之间颜色与图标交叉淡入，不闪
class TianjiConnectRing extends ConsumerStatefulWidget {
  /// 环的直径。窄屏给小一点
  final double size;

  const TianjiConnectRing({super.key, this.size = 208});

  @override
  ConsumerState<TianjiConnectRing> createState() => _TianjiConnectRingState();
}

class _TianjiConnectRingState extends ConsumerState<TianjiConnectRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // 🔴 只在连接时转。常驻动画在桌面端是持续的 GPU 占用，
    //    而未连接时它也没有任何要表达的东西。
    _syncBreath(ref.read(isStartProvider));
  }

  void _syncBreath(bool running) {
    if (running) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final tj = context.tj;
    final accent = context.colorScheme.primary;
    final running = ref.watch(isStartProvider) && !ref.watch(suspendProvider);
    final hasProfile = ref.watch(profilesProvider.select((s) => s.isNotEmpty));
    final main = ref.watch(tianjiMainGroupProvider);
    final delay = main == null
        ? null
        : ref.watch(delayProvider(proxyName: main.name, testUrl: main.testUrl));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncBreath(running);
    });

    // 🔴 测不出就是「—」，不是 0 ms
    final delayText = !running || delay == null || delay == 0
        ? '—'
        : delay < 0
        ? l.tianjiTimeout
        : '$delay';
    final showsUnit = running && delay != null && delay > 0;

    final ringColor = running ? accent : tj.unknown;
    final d = widget.size;

    return Semantics(
      button: true,
      label: running ? l.tianjiDisconnect : l.tianjiConnect,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: hasProfile
            ? () => ref.read(commonActionProvider.notifier).toggleRunning()
            : () => ref
                  .read(tianjiSettingProvider.notifier)
                  .update((s) => s.copyWith(skipLogin: false)),
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (context, child) {
              // 0 → 1 → 0，配合 reverse:true 就是一次完整的呼吸
              final t = Curves.easeInOut.transform(_breath.value);
              return Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ringColor.withValues(
                        alpha: running ? 0.18 + 0.16 * t : 0.10,
                      ),
                      blurRadius: 30 + 18 * t,
                      spreadRadius: 2 + 6 * t,
                    ),
                  ],
                ),
                child: child,
              );
            },
            child: _Face(
              size: d,
              color: ringColor,
              running: running,
              hasProfile: hasProfile,
              delayText: delayText,
              showsUnit: showsUnit,
            ),
          ),
        ),
      ),
    );
  }
}

/// 环本身。拆出来是为了让上面的呼吸动画只重建一层 —— 环内有文字与图标，
/// 每帧重建它们是白烧 CPU。
class _Face extends StatelessWidget {
  final double size;
  final Color color;
  final bool running;
  final bool hasProfile;
  final String delayText;
  final bool showsUnit;

  const _Face({
    required this.size,
    required this.color,
    required this.running,
    required this.hasProfile,
    required this.delayText,
    required this.showsUnit,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, c, _) {
        final col = c ?? color;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(col, Colors.white, 0.18)!,
                col,
                Color.lerp(col, Colors.black, 0.22)!,
              ],
              stops: const [0, 0.55, 1],
            ),
          ),
          // 内圈留一道浅边，把中心的字从渐变里托起来
          child: Padding(
            padding: EdgeInsets.all(size * 0.055),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      running ? Icons.power_settings_new : Icons.bolt,
                      size: size * 0.17,
                      color: Colors.white,
                    ),
                    SizedBox(height: size * 0.035),
                    Text(
                      !hasProfile
                          ? l.tianjiNoProfile
                          : running
                          ? l.tianjiConnected
                          : l.tianjiDisconnected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.088,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (running) ...[
                      SizedBox(height: size * 0.012),
                      // 🔴 延迟用等宽数字：它每 5 分钟变一次，不等宽会整行跳动
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            delayText,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: size * 0.082,
                              fontWeight: FontWeight.w500,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          if (showsUnit)
                            Text(
                              ' ms',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: size * 0.058,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
