import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首页：一个大按钮 + 当前线路 + AI 服务实测 + 当前速率。
///
/// 🔴 页面上没有一个数字是写死的：延迟来自内核实测，AI 状态来自状态页公开数据，
///    速率来自内核流量计数。取不到就显示「暂时无法获取」，不回落任何示意值。
class TianjiHomeView extends ConsumerWidget {
  const TianjiHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(tianjiSettingProvider.select((s) => s.email));
    return CommonScaffold(
      title: context.appLocalizations.tianjiProfileLabel,
      actions: [
        if (email.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => ref
                  .read(currentPageLabelProvider.notifier)
                  .toPage(PageLabel.tools),
              icon: const Icon(Icons.person_outline, size: 18),
              label: Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall,
              ),
            ),
          ),
      ],
      body: const _HomeBody(),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 8),
              _PowerButton(),
              SizedBox(height: 18),
              _LinePill(),
              SizedBox(height: 20),
              _AiServicesCard(),
              SizedBox(height: 16),
              _SpeedRow(),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// 大按钮：点一下开关，长按重新测速。按钮上是状态和当前真实线路的延迟。
class _PowerButton extends ConsumerWidget {
  const _PowerButton();

  String _delayText(BuildContext context, int? delay) {
    if (delay == null || delay == 0) return '—';
    if (delay < 0) return context.appLocalizations.tianjiTimeout;
    return '$delay ms';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final isStart = ref.watch(isStartProvider);
    final suspend = ref.watch(suspendProvider);
    final hasProfile = ref.watch(
      profilesProvider.select((state) => state.isNotEmpty),
    );
    final main = ref.watch(tianjiMainGroupProvider);
    final delay = main == null
        ? null
        : ref.watch(delayProvider(proxyName: main.name, testUrl: main.testUrl));
    final running = isStart && !suspend;
    final bg = running
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final fg = running ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final label = !hasProfile
        ? appLocalizations.tianjiNoProfile
        : running
        ? appLocalizations.tianjiConnected
        : appLocalizations.tianjiDisconnected;
    return Column(
      children: [
        Semantics(
          button: true,
          label: label,
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            elevation: running ? 6 : 0,
            shadowColor: colorScheme.primary.withValues(alpha: 0.4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: hasProfile
                  ? () =>
                        ref.read(commonActionProvider.notifier).toggleRunning()
                  : () => ref
                        .read(currentPageLabelProvider.notifier)
                        .toPage(PageLabel.profiles),
              onLongPress: running
                  ? () => ref
                        .read(tianjiActionProvider.notifier)
                        .optimizeAfterNetworkChange()
                  : null,
              child: SizedBox(
                width: 176,
                height: 176,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.power_settings_new, size: 40, color: fg),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: context.textTheme.titleMedium?.copyWith(color: fg),
                    ),
                    if (running) ...[
                      const SizedBox(height: 2),
                      Text(
                        _delayText(context, delay),
                        style: context.textTheme.titleLarge?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          running
              ? appLocalizations.tianjiTapToDisconnect
              : appLocalizations.tianjiTapToConnect,
          style: context.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 「自动选择 → 香港 · 01 ›」：主分组当前选的项，和它背后真正在用的线路。点进线路页。
class _LinePill extends ConsumerWidget {
  const _LinePill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final main = ref.watch(tianjiMainGroupProvider);
    final selected = main == null
        ? null
        : ref.watch(selectedProxyNameProvider(main.name));
    final real = main == null
        ? ''
        : ref.watch(realSelectedProxyStateProvider(main.name)).proxyName;
    final text = main == null
        ? appLocalizations.tianjiNoLine
        : (selected == null || selected.isEmpty || selected == real)
        ? tianjiBaseAlias(real)
        : '$selected  →  ${tianjiBaseAlias(real)}';
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () =>
            ref.read(currentPageLabelProvider.notifier).toPage(PageLabel.lines),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.alt_route, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                appLocalizations.tianjiLine,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AI 服务实测：当前真实线路上，状态页对每个服务的结论。
class _AiServicesCard extends ConsumerWidget {
  const _AiServicesCard();

  static const _shown = ['ChatGPT', 'Claude', 'Gemini'];

  String _ago(BuildContext context, int? since) {
    if (since == null || since <= 0) return '';
    final l = context.appLocalizations;
    final sec = DateTime.now().millisecondsSinceEpoch ~/ 1000 - since;
    if (sec < 90) return l.tianjiJustNow;
    if (sec < 3600) return l.tianjiAgoMinutes(sec ~/ 60);
    if (sec < 86400) return l.tianjiAgoHours(sec ~/ 3600);
    return l.tianjiAgoDays(sec ~/ 86400);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final status = ref.watch(tianjiAiStatusStateProvider);
    final main = ref.watch(tianjiMainGroupProvider);
    final real = main == null
        ? ''
        : ref.watch(realSelectedProxyStateProvider(main.name)).proxyName;
    final node = status?.forNode(real);
    final rows = _shown.map((service) {
      final s = node?[service];
      final Color dot;
      final String text;
      if (status == null) {
        dot = colorScheme.outlineVariant;
        text = appLocalizations.tianjiAiNoData;
      } else if (s == null || s.state == 'unknown') {
        dot = colorScheme.outline;
        text = appLocalizations.tianjiAiUnknown;
      } else if (s.available) {
        dot = const Color(0xFF34C759);
        text = appLocalizations.tianjiAiAvailable;
      } else {
        dot = colorScheme.error;
        text = appLocalizations.tianjiAiOffline;
      }
      final ago = s == null ? '' : _ago(context, s.since);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(service, style: context.textTheme.bodyMedium)),
            Text(
              ago.isEmpty ? text : '$text · $ago',
              style: context.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appLocalizations.tianjiAiServices,
                  style: context.textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: () => globalState.openUrl(tianjiStatusUrl),
                child: Text(appLocalizations.tianjiAiAll),
              ),
            ],
          ),
          ...rows,
          if (status != null && real.isNotEmpty && node == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                appLocalizations.tianjiAiNotProbed,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 当前速率：内核每秒上报的上下行字节数，不是带宽测速。
class _SpeedRow extends ConsumerWidget {
  const _SpeedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.colorScheme;
    final traffics = ref.watch(trafficsProvider).list;
    final t = traffics.isEmpty ? const Traffic() : traffics.last;
    final style = context.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.arrow_downward, size: 14, color: colorScheme.primary),
        const SizedBox(width: 4),
        Text('${t.down.traffic.show}/s', style: style),
        const SizedBox(width: 20),
        Icon(Icons.arrow_upward, size: 14, color: colorScheme.primary),
        const SizedBox(width: 4),
        Text('${t.up.traffic.show}/s', style: style),
      ],
    );
  }
}
