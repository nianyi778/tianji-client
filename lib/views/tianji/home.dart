import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首页仪表盘。
///
/// 🔴 页面上没有一个数字是写死或推算的：延迟来自内核实测、速率来自内核每秒计数、
///    用量来自订阅信息、AI 状态来自状态页的公开实测。取不到就写「暂时无法获取」，
///    绝不回落到好看的示意值（CLAUDE.md 红线 6）。
///
/// 🔴 设计稿里「线路推荐」有丢包率与负载两列 —— **客户端测不到**，没有做。
///    宁可少两列，也不放一个我们没有量过的数字。替代的是延迟与 AI 可用性，那两样是真的。
///
/// 宽屏两栏（左：连接与流量；右：线路与连接信息），窄屏单栏依次排开。
class TianjiHomeView extends ConsumerWidget {
  const TianjiHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CommonScaffold(
      title: context.appLocalizations.home,
      actions: const [
        _AccountChip(),
        SizedBox(width: tjGap3),
      ],
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          const left = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ConnectionCard(),
              SizedBox(height: tjGap3),
              _MeterRow(),
              SizedBox(height: tjGap3),
              _TrafficChartCard(),
              SizedBox(height: tjGap3),
              _AiServicesCard(),
            ],
          );
          const right = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LineListCard(),
              SizedBox(height: tjGap3),
              _ConnectionInfoCard(),
            ],
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.all(tjGap4),
            child: wide
                ? const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: left),
                      SizedBox(width: tjGap3),
                      SizedBox(width: 340, child: right),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left,
                      SizedBox(height: tjGap3),
                      right,
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// 卡片外壳：整页只有这一个卡片定义，边距圆角全站一致。
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(tjGap4),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.tj.card,
      borderRadius: BorderRadius.circular(tjRadiusCard),
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const _CardTitle(this.text, {this.trailing});

  @override
  // 🔴 标题与右侧动作都要能压缩：窄屏下「实时流量」+「全部实测」会溢出。
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      if (trailing != null)
        Flexible(
          child: FittedBox(fit: BoxFit.scaleDown, child: trailing),
        ),
    ],
  );
}

/// 右上角的账号胶囊：邮箱 + 套餐名（套餐名来自 Xboard，取不到就不显示）。
class _AccountChip extends ConsumerWidget {
  const _AccountChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(tianjiSettingProvider.select((s) => s.email));
    if (email.isEmpty) return const SizedBox.shrink();
    // 🔴 顶栏是一个 Row，邮箱可以很长 —— 不限宽会把整条标题行撑爆
    //    （2026-10-01 widget 测试在 380px 宽下逮到，溢出 31px）。
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: TextButton.icon(
        onPressed: () =>
            ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.tools),
        icon: const Icon(Icons.account_circle_outlined, size: 20),
        label: Text(
          email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: context.textTheme.bodySmall,
        ),
      ),
    );
  }
}

// ── 连接卡 ─────────────────────────────────────────────────────────────
class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final cs = context.colorScheme;
    final tj = context.tj;
    final running = ref.watch(isStartProvider) && !ref.watch(suspendProvider);
    final hasProfile = ref.watch(profilesProvider.select((s) => s.isNotEmpty));
    final main = ref.watch(tianjiMainGroupProvider);
    final delay = main == null
        ? null
        : ref.watch(delayProvider(proxyName: main.name, testUrl: main.testUrl));
    final real = main == null
        ? ''
        : ref.watch(realSelectedProxyStateProvider(main.name)).proxyName;

    return _Card(
      padding: const EdgeInsets.all(tjGap5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 状态圆点：连接态用主色，未连接用中性色，不用红 ——
              // 「没连」不是故障。
              AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: running
                      ? tj.good.withValues(alpha: 0.14)
                      : tj.ink3.withValues(alpha: 0.12),
                ),
                child: Icon(
                  running ? Icons.check_rounded : Icons.power_settings_new,
                  color: running ? tj.good : tj.ink3,
                  size: 24,
                ),
              ),
              const SizedBox(width: tjGap3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !hasProfile
                          ? l.tianjiNoProfile
                          : running
                          ? l.tianjiConnected
                          : l.tianjiDisconnected,
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      running
                          ? l.tianjiConnectedDesc
                          : l.tianjiDisconnectedDesc,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: tj.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: tjGap4),
          // 🔴 窄屏（~380px）按钮与线路胶囊并排放不下，会溢出 31px ——
          //    2026-10-01 widget 测试逮到。窄屏改成上下两行。
          LayoutBuilder(
            builder: (context, c) {
              final button = FilledButton.icon(
                onPressed: hasProfile
                    ? () => ref
                          .read(commonActionProvider.notifier)
                          .toggleRunning()
                    : () => ref
                          .read(tianjiSettingProvider.notifier)
                          .update((s) => s.copyWith(skipLogin: false)),
                style: running
                    ? FilledButton.styleFrom(
                        backgroundColor: cs.surfaceContainerHighest,
                        foregroundColor: cs.onSurface,
                      )
                    : null,
                icon: Icon(running ? Icons.link_off : Icons.bolt, size: 18),
                label: Text(running ? l.tianjiDisconnect : l.tianjiConnect),
              );
              final pill = _LinePill(
                name: real,
                delay: delay,
                running: running,
              );
              if (c.maxWidth < 420) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    button,
                    const SizedBox(height: tjGap3),
                    pill,
                  ],
                );
              }
              return Row(
                children: [
                  button,
                  const SizedBox(width: tjGap3),
                  Expanded(child: pill),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 当前线路胶囊 + 延迟。点进线路页。
class _LinePill extends ConsumerWidget {
  final String name;
  final int? delay;
  final bool running;
  const _LinePill({
    required this.name,
    required this.delay,
    required this.running,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tj = context.tj;
    final l = context.appLocalizations;
    final text = delay == null || delay == 0
        ? '—'
        : delay! < 0
        ? l.tianjiTimeout
        : '$delay ms';
    return Material(
      color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(tjRadiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(tjRadiusPill),
        onTap: () =>
            ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.lines),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: tjGap4, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.alt_route,
                size: 16,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: tjGap2),
              Expanded(
                child: Text(
                  name.isEmpty ? l.tianjiNoLine : tianjiBaseAlias(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium,
                ),
              ),
              if (running) ...[
                Text(
                  text,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: tj.ink2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: tjGap2),
              ],
              Icon(Icons.chevron_right, size: 18, color: tj.ink3),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 上传 / 下载 / 用量 ──────────────────────────────────────────────────
class _MeterRow extends ConsumerWidget {
  const _MeterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider).list;
    final t = traffics.isEmpty ? const Traffic() : traffics.last;
    return _Card(
      child: Row(
        children: [
          Expanded(
            child: _Meter(
              icon: Icons.arrow_upward,
              label: l.tianjiUpload,
              value: '${t.up.traffic.show}/s',
            ),
          ),
          _MeterDivider(),
          Expanded(
            child: _Meter(
              icon: Icons.arrow_downward,
              label: l.tianjiDownload,
              value: '${t.down.traffic.show}/s',
            ),
          ),
          _MeterDivider(),
          const Expanded(child: _UsageMeter()),
        ],
      ),
    );
  }
}

class _MeterDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 38, color: context.tj.line);
}

class _Meter extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Meter({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: context.tj.ink3),
          const SizedBox(width: tjGap1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.tj.ink3,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      // 🔴 数值必须能省略：窄屏三个仪表并排时，「1024.00 GB / 1024 GB」会把整行撑爆
      //    （2026-10-01 widget 测试逮到过一次，溢出 31px）。
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          maxLines: 1,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  );
}

/// 已用流量。数据来自订阅信息；🔴 取不到就显示「暂时无法获取」，不编。
class _UsageMeter extends ConsumerWidget {
  const _UsageMeter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final info = ref.watch(
      currentProfileProvider.select((p) => p?.subscriptionInfo),
    );
    final value = info == null
        ? l.tianjiAiNoData
        : '${((info.upload + info.download) / 1073741824).toStringAsFixed(2)} GB'
              '${info.total > 0 ? ' / ${(info.total / 1073741824).toStringAsFixed(0)} GB' : ''}';
    return _Meter(icon: Icons.donut_large, label: l.tianjiUsed, value: value);
  }
}

// ── 实时流量 ───────────────────────────────────────────────────────────
class _TrafficChartCard extends ConsumerWidget {
  const _TrafficChartCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final traffics = ref.watch(trafficsProvider).list;
    final pts = <Point>[];
    for (var i = 0; i < traffics.length; i++) {
      pts.add(Point(i.toDouble(), traffics[i].speed.toDouble()));
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(l.tianjiRealtimeTraffic),
          const SizedBox(height: tjGap3),
          SizedBox(
            height: 132,
            child: pts.length < 2
                ? Center(
                    child: Text(
                      l.tianjiChartWaiting,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.tj.ink3,
                      ),
                    ),
                  )
                : LineChart(
                    points: pts,
                    color: context.colorScheme.primary,
                    gradient: true,
                  ),
          ),
        ],
      ),
    );
  }
}

// ── AI 服务状态 ────────────────────────────────────────────────────────
class _AiServicesCard extends ConsumerWidget {
  const _AiServicesCard();

  static const _shown = ['ChatGPT', 'Claude', 'Gemini', 'Perplexity'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final status = ref.watch(tianjiAiStatusStateProvider);
    final notifier = ref.read(tianjiAiStatusStateProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => notifier.refreshIfStale(),
    );
    final main = ref.watch(tianjiMainGroupProvider);
    final real = main == null
        ? ''
        : ref.watch(realSelectedProxyStateProvider(main.name)).proxyName;
    final node = status?.forNode(real);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            l.tianjiAiServices,
            trailing: TextButton(
              onPressed: () => globalState.openUrl(tianjiStatusUrl),
              child: Text(l.tianjiAiAll),
            ),
          ),
          const SizedBox(height: tjGap3),
          // 🔴 这里不能用 GridView 的 childAspectRatio —— 那是**固定**行高，
          //    用户把系统字号调大、或者状态文案换成更长的语言，格子里的两行字
          //    就顶破格子（widget 测试逮到过，溢出 33px）。用 Wrap 只定宽不定高，
          //    高度由内容自己撑。
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 560 ? 4 : 2;
              final w = (c.maxWidth - tjGap2 * (cols - 1)) / cols;
              return Wrap(
                spacing: tjGap2,
                runSpacing: tjGap2,
                children: [
                  for (final s in _shown)
                    SizedBox(
                      width: w,
                      child: _AiTile(
                        service: s,
                        state: node?[s],
                        hasData: status != null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiTile extends StatelessWidget {
  final String service;
  final TianjiAiServiceState? state;
  final bool hasData;
  const _AiTile({
    required this.service,
    required this.state,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final tj = context.tj;
    final Color dot;
    final String text;
    if (!hasData) {
      dot = tj.unknown;
      text = l.tianjiAiNoData;
    } else if (state == null || state!.state == 'unknown') {
      dot = tj.unknown;
      text = l.tianjiAiUnknown;
    } else if (state!.available) {
      dot = tj.good;
      text = l.tianjiAiAvailable;
    } else {
      dot = tj.bad;
      text = l.tianjiAiOffline;
    }
    return Container(
      padding: const EdgeInsets.all(tjGap3),
      decoration: BoxDecoration(
        color: context.tj.ground,
        borderRadius: BorderRadius.circular(tjRadiusControl),
        border: Border.all(color: tj.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            service,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: tjGap2),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(color: tj.ink2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 右栏：线路 ─────────────────────────────────────────────────────────
class _LineListCard extends ConsumerWidget {
  const _LineListCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final main = ref.watch(tianjiMainGroupProvider);
    final members = main == null
        ? const <String>[]
        : main.all.map((e) => e.name).toList();
    final selected = main == null
        ? null
        : ref.watch(selectedProxyNameProvider(main.name));
    final rows = buildTianjiLineRows(
      members: members,
      selectedName: selected,
      resolveReal: (n) => ref.read(realSelectedProxyStateProvider(n)).proxyName,
    ).where((r) => !r.locked).take(6).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(
            l.tianjiLines,
            trailing: TextButton(
              onPressed: () => ref
                  .read(currentPageLabelProvider.notifier)
                  .toPage(PageLabel.lines),
              child: Text(l.tianjiAllLines),
            ),
          ),
          const SizedBox(height: tjGap2),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: tjGap3),
              child: Text(
                l.tianjiNoLine,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.tj.ink3,
                ),
              ),
            )
          else
            for (final r in rows)
              _LineRow(row: r, groupName: main!.name, testUrl: main.testUrl),
        ],
      ),
    );
  }
}

class _LineRow extends ConsumerWidget {
  final TianjiLineRow row;
  final String groupName;
  final String? testUrl;
  const _LineRow({
    required this.row,
    required this.groupName,
    required this.testUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tj = context.tj;
    final delay = ref.watch(
      delayProvider(proxyName: row.name, testUrl: testUrl),
    );
    final status = ref.watch(tianjiAiStatusStateProvider);
    final node = status?.forNode(row.realName);
    final aiOk = node?.values.where((v) => v.available).length;
    return InkWell(
      borderRadius: BorderRadius.circular(tjRadiusControl),
      onTap: () async {
        await ref
            .read(proxiesActionProvider.notifier)
            .changeProxy(groupName: groupName, proxyName: row.name);
        ref
            .read(profilesActionProvider.notifier)
            .updateCurrentSelectedMap(groupName, row.name);
        ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: tjGap2),
        child: Row(
          children: [
            Icon(
              row.selected ? Icons.check_circle : Icons.circle_outlined,
              size: 17,
              color: row.selected ? context.colorScheme.primary : tj.line,
            ),
            const SizedBox(width: tjGap3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tianjiBaseAlias(row.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium,
                  ),
                  if (aiOk != null)
                    Text(
                      context.appLocalizations.tianjiAiOkCount(aiOk),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: aiOk > 0 ? tj.good : tj.ink3,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              delay == null || delay == 0
                  ? '—'
                  : delay < 0
                  ? context.appLocalizations.tianjiTimeout
                  : '$delay ms',
              style: context.textTheme.bodySmall?.copyWith(
                color: tj.ink2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 右栏：连接信息 ─────────────────────────────────────────────────────
class _ConnectionInfoCard extends ConsumerWidget {
  const _ConnectionInfoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final tj = context.tj;
    final main = ref.watch(tianjiMainGroupProvider);
    final real = main == null
        ? ''
        : ref.watch(realSelectedProxyStateProvider(main.name)).proxyName;
    final ipInfo = ref.watch(networkDetectionProvider).ipInfo;
    final runTime = ref.watch(runTimeProvider);
    final dns = ref.watch(patchClashConfigProvider.select((s) => s.dns.enable));

    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: context.textTheme.bodySmall?.copyWith(color: tj.ink3),
            ),
          ),
          Flexible(
            child: Text(
              v,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: context.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardTitle(l.tianjiConnectionInfo),
          const SizedBox(height: tjGap2),
          row(l.tianjiLine, real.isEmpty ? '—' : tianjiBaseAlias(real)),
          // 🔴 出口 IP 与地区来自实测；没测出来就是 —，不猜
          row(l.tianjiExitIp, ipInfo?.ip ?? '—'),
          row(l.tianjiExitRegion, ipInfo?.countryCode ?? '—'),
          row('DNS', dns ? l.tianjiDnsRemote : l.tianjiDnsSystem),
          row(l.tianjiUptime, utils.getTimeText(runTime)),
        ],
      ),
    );
  }
}
