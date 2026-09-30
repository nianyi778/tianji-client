import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 桌面端侧栏 —— 深色渐变底，品牌标在顶、连接状态在底。
///
/// 🔴 这一栏**始终是深色**，不跟随明暗主题。设计稿里它是品牌区，和右侧的内容区
///    形成对比；跟着主题翻成浅色就失去了这个层次，也和官网的视觉对不上。
///    所以这里的颜色不走 `context.tj`（那是内容区的令牌），自己定义一套。
class TianjiSidebar extends ConsumerWidget {
  final List<NavigationItem> items;
  final int currentIndex;
  final ValueChanged<PageLabel> onSelect;

  const TianjiSidebar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  // 侧栏自己的色板。与官网深色底同源。
  static const _top = Color(0xFF12294D);
  static const _bottom = Color(0xFF0A1729);
  static const _label = Color(0xFFB8C6DC);
  static const _labelDim = Color(0xFF7C8CA6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 208,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_top, _bottom],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 底部的山影。纯装饰，用 Canvas 画，不引入图片资源。
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 220,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: TianjiRidgePainter(color: Color(0x0FFFFFFF)),
                ),
              ),
            ),
            // 🔴 侧栏在「手机↔桌面」切换的动画帧里高度会被压到极小，
            //    固定高度的 Column 会溢出几十万像素。包一层滚动容器兜住。
            SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // macOS 的红绿灯按钮占着左上角，标要往下让
                      SizedBox(height: system.isMacOS ? 34 : tjGap5),
                      const _Brand(),
                      const SizedBox(height: tjGap5),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: tjGap3),
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              _NavItem(
                                item: items[i],
                                selected: i == currentIndex,
                                onTap: () => onSelect(items[i].label),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: tjGap5),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(tjGap3, 0, tjGap3, tjGap3),
                        child: _StatusCard(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: tjGap4),
    child: Row(
      children: [
        Image.asset('assets/images/icon.png', width: 34, height: 34),
        const SizedBox(width: tjGap2),
        // 🔴 必须 Expanded + 省略号：侧栏只有 208 宽，标语稍长就把这一行撑爆
        //    （widget 测试逮到过，溢出 45px）。
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                appDisplayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Text(
                context.appLocalizations.tianjiTagline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall?.copyWith(
                  color: TianjiSidebar._labelDim,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  final NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: tjGap1),
      child: Material(
        color: selected ? accent : Colors.transparent,
        borderRadius: BorderRadius.circular(tjRadiusControl),
        child: InkWell(
          borderRadius: BorderRadius.circular(tjRadiusControl),
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: tjGap3,
              vertical: 11,
            ),
            child: Row(
              children: [
                IconTheme(
                  data: IconThemeData(
                    size: 19,
                    color: selected ? Colors.white : TianjiSidebar._label,
                  ),
                  child: item.icon,
                ),
                const SizedBox(width: tjGap3),
                Flexible(
                  child: Text(
                    Intl.message(item.label.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: selected ? Colors.white : TianjiSidebar._label,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _version() {
  try {
    return 'v${globalState.packageInfo.version}';
  } catch (_) {
    return '';
  }
}

/// 侧栏底部的连接状态。🔴 只显示我们真的知道的：连没连、当前线路、版本号。
class _StatusCard extends ConsumerWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final running = ref.watch(isStartProvider) && !ref.watch(suspendProvider);
    final main = ref.watch(tianjiMainGroupProvider);
    final real = main == null
        ? ''
        : ref.watch(realSelectedProxyStateProvider(main.name)).proxyName;
    return Container(
      padding: const EdgeInsets.all(tjGap3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(tjRadiusControl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: running
                      ? const Color(0xFF34C759)
                      : TianjiSidebar._labelDim,
                ),
              ),
              const SizedBox(width: tjGap2),
              // 🔴 同样要能省略：侧栏很窄，状态文字在其它语言下会更长
              Expanded(
                child: Text(
                  running ? l.tianjiConnected : l.tianjiDisconnected,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (running && real.isNotEmpty) ...[
            const SizedBox(height: tjGap1),
            Text(
              tianjiBaseAlias(real),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: TianjiSidebar._label,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: tjGap2),
          // 🔴 packageInfo 是 late，app 初始化完成前读它会抛 LateError。
          //    侧栏可能先于初始化被构建（widget 测试里就是），所以要兜住。
          Text(
            _version(),
            style: context.textTheme.labelSmall?.copyWith(
              color: TianjiSidebar._labelDim,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
