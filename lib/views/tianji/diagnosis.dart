import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 诊断页：给结论和一个能点的动作，不给日志。
///
/// 🔴 每一项都是这台设备此刻真的测出来的，判定规则与 checker 对齐（见 tianji_probe.dart）。
///    测不出就写「测不出」，绝不算成「不可用」——把自己的探测失败报成线路故障会引发退款潮。
class TianjiDiagnosisView extends ConsumerStatefulWidget {
  const TianjiDiagnosisView({super.key});

  @override
  ConsumerState<TianjiDiagnosisView> createState() =>
      _TianjiDiagnosisViewState();
}

class _TianjiDiagnosisViewState extends ConsumerState<TianjiDiagnosisView> {
  bool _running = false;
  String? _exitIp;
  String? _region;
  bool _exitProbed = false;
  final Map<String, TianjiProbeState> _ai = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(isStartProvider)) _run();
    });
  }

  /// 探测用的客户端：走本地代理（内核在跑时），带浏览器 UA，不跟随重定向。
  /// 🔴 不跟随重定向 —— 地区封锁常表现为跳到落地页，跟过去会被误判成「可用」。
  Dio _probeDio() {
    final dio = tianjiDio();
    dio.options = dio.options.copyWith(
      responseType: ResponseType.plain,
      followRedirects: false,
      maxRedirects: 0,
      receiveTimeout: const Duration(seconds: 12),
      headers: {'User-Agent': tianjiProbeUserAgent},
    );
    return dio;
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _exitProbed = false;
      _exitIp = null;
      _region = null;
      _ai.clear();
    });
    try {
      final ipRes = await request.checkIp();
      if (!mounted) return;
      final info = ipRes.isSuccess ? ipRes.data : null;
      setState(() {
        _exitProbed = true;
        _exitIp = info?.ip;
        _region = info?.countryCode;
      });

      final dio = _probeDio();
      await Future.wait(
        tianjiAiTargets.map((t) async {
          int? code;
          var body = '';
          try {
            final res = await dio.get<String>(t.url);
            code = res.statusCode;
            body = res.data ?? '';
          } catch (e) {
            commonPrint.log(
              'tianji probe ${t.service} failed: $e',
              logLevel: LogLevel.info,
            );
          }
          final state = classifyTianjiProbe(
            target: t,
            statusCode: code,
            body: body,
          );
          if (mounted) setState(() => _ai[t.service] = state);
        }),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  /// 建议切过去的线路：主分组里延迟最低、活着、没锁住、且不是当前这条。
  String? _suggestedLine() {
    final main = ref.read(tianjiMainGroupProvider);
    if (main == null) return null;
    final current = ref.read(selectedProxyNameProvider(main.name));
    String? best;
    int bestDelay = 1 << 30;
    for (final p in main.all) {
      if (p.name == current || tianjiIsLocked(p.name)) continue;
      final real = ref.read(realSelectedProxyStateProvider(p.name)).proxyName;
      if (tianjiIsLocked(real)) continue;
      final d = ref.read(
        delayProvider(proxyName: p.name, testUrl: main.testUrl),
      );
      if (d == null || d <= 0 || d >= bestDelay) continue;
      bestDelay = d;
      best = p.name;
    }
    return best;
  }

  Future<void> _switchTo(String line) async {
    final main = ref.read(tianjiMainGroupProvider);
    if (main == null) return;
    await ref
        .read(proxiesActionProvider.notifier)
        .changeProxy(groupName: main.name, proxyName: line);
    ref
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap(main.name, line);
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
    await _run();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final isStart = ref.watch(isStartProvider);
    final suspend = ref.watch(suspendProvider);
    final dns = ref.watch(patchClashConfigProvider.select((s) => s.dns));
    final verdict = tianjiVerdict(
      running: isStart && !suspend,
      exitIp: _exitProbed ? (_exitIp ?? '') : null,
      ai: _ai,
      suggestedLine: _suggestedLine(),
    );
    return CommonScaffold(
      title: appLocalizations.tianjiDiagnosis,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _VerdictCard(verdict: verdict, busy: _running, onAction: _switchTo),
          const SizedBox(height: 16),
          _CheckRow(
            title: appLocalizations.tianjiExitRegion,
            detail: _exitProbed
                ? (_region?.isNotEmpty == true
                      ? _region!
                      : appLocalizations.tianjiUnmeasured)
                : '',
            level: !_exitProbed
                ? TianjiCheckLevel.unknown
                : (_region?.isNotEmpty == true
                      ? TianjiCheckLevel.ok
                      : TianjiCheckLevel.unknown),
            busy: _running && !_exitProbed,
          ),
          _CheckRow(
            title: appLocalizations.tianjiIpVersion,
            detail: !_exitProbed || _exitIp == null
                ? ''
                : (tianjiIsIpv6(_exitIp!)
                      ? appLocalizations.tianjiIpv6Exit
                      : appLocalizations.tianjiIpv4Exit),
            level: !_exitProbed || _exitIp == null
                ? TianjiCheckLevel.unknown
                : (tianjiIsIpv6(_exitIp!)
                      ? TianjiCheckLevel.warn
                      : TianjiCheckLevel.ok),
            busy: _running && !_exitProbed,
          ),
          _CheckRow(
            title: 'DNS',
            detail: dns.enable
                ? appLocalizations.tianjiDnsRemote
                : appLocalizations.tianjiDnsSystem,
            level: dns.enable ? TianjiCheckLevel.ok : TianjiCheckLevel.warn,
          ),
          const Divider(height: 24),
          for (final t in tianjiAiTargets)
            _CheckRow(
              title: t.service,
              detail: switch (_ai[t.service]) {
                TianjiProbeState.available =>
                  appLocalizations.tianjiAiAvailable,
                TianjiProbeState.unavailable =>
                  appLocalizations.tianjiAiOffline,
                TianjiProbeState.unknown => appLocalizations.tianjiUnmeasured,
                null => '',
              },
              level: switch (_ai[t.service]) {
                TianjiProbeState.available => TianjiCheckLevel.ok,
                TianjiProbeState.unavailable => TianjiCheckLevel.bad,
                _ => TianjiCheckLevel.unknown,
              },
              busy: _running && !_ai.containsKey(t.service),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _running || !(isStart && !suspend) ? null : _run,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(appLocalizations.tianjiRecheck),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            appLocalizations.tianjiDiagnosisFoot,
            textAlign: TextAlign.center,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

Color _levelColor(BuildContext context, TianjiCheckLevel level) =>
    switch (level) {
      TianjiCheckLevel.ok => const Color(0xFF34C759),
      TianjiCheckLevel.warn => const Color(0xFFFF9F0A),
      TianjiCheckLevel.bad => context.colorScheme.error,
      TianjiCheckLevel.unknown => context.colorScheme.outlineVariant,
    };

class _VerdictCard extends StatelessWidget {
  final TianjiVerdict verdict;
  final bool busy;
  final Future<void> Function(String line) onAction;

  const _VerdictCard({
    required this.verdict,
    required this.busy,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final color = _levelColor(context, verdict.level);
    final names = verdict.services.join(' / ');
    final (String title, String detail) = switch (verdict.code) {
      'notRunning' => (
        l.tianjiVerdictNotRunning,
        l.tianjiVerdictNotRunningDesc,
      ),
      'noExit' => (l.tianjiVerdictNoExit, l.tianjiVerdictNoExitDesc),
      'aiDown' => (l.tianjiVerdictAiDown(names), l.tianjiVerdictAiDownDesc),
      'aiDownIpv6' => (
        l.tianjiVerdictAiDown(names),
        l.tianjiVerdictAiDownIpv6Desc,
      ),
      'ipv6' => (l.tianjiVerdictIpv6, l.tianjiVerdictIpv6Desc),
      'partialUnknown' => (l.tianjiVerdictPartial, l.tianjiVerdictPartialDesc),
      _ => (l.tianjiVerdictAllGood, l.tianjiVerdictAllGoodDesc),
    };
    final line = verdict.suggestedLine;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  busy ? l.tianjiChecking : title,
                  style: context.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (!busy) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: context.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (line != null &&
                (verdict.level == TianjiCheckLevel.bad ||
                    verdict.level == TianjiCheckLevel.warn)) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => onAction(line),
                child: Text(l.tianjiSwitchTo(tianjiBaseAlias(line))),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final String title;
  final String detail;
  final TianjiCheckLevel level;
  final bool busy;

  const _CheckRow({
    required this.title,
    required this.detail,
    required this.level,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          busy
              ? const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              : Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _levelColor(context, level),
                    shape: BoxShape.circle,
                  ),
                ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: context.textTheme.bodyMedium)),
          Text(
            detail,
            style: context.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
