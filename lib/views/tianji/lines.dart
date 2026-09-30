import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/common.dart';
import 'package:fl_clash/views/tianji/anim.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 线路页：只列主分组的成员，不把几十个节点摊开。
///
/// 🔴 买不起这一档的人看到的是订阅里的占位项（带 🔒），这里灰掉并说明「需升级套餐」，
///    点它跳购买页 —— 页面上不写价格、不写流量，那些是后台配的（CLAUDE.md 第一条）。
class TianjiLinesView extends ConsumerStatefulWidget {
  const TianjiLinesView({super.key});

  @override
  ConsumerState<TianjiLinesView> createState() => _TianjiLinesViewState();
}

class _TianjiLinesViewState extends ConsumerState<TianjiLinesView> {
  bool _testing = false;

  Future<void> _retest() async {
    final main = ref.read(tianjiMainGroupProvider);
    if (main == null || _testing) return;
    setState(() => _testing = true);
    try {
      await delayTest(main.all, main.testUrl);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final main = ref.watch(tianjiMainGroupProvider);
    return CommonScaffold(
      title: appLocalizations.tianjiLines,
      actions: [
        TextButton.icon(
          onPressed: main == null || _testing ? null : _retest,
          icon: _testing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(appLocalizations.tianjiRetest),
        ),
        const SizedBox(width: 8),
      ],
      body: main == null
          ? Center(
              child: Text(
                appLocalizations.tianjiNoLine,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.tj.ink3,
                ),
              ),
            )
          : _LineList(groupName: main.name, testUrl: main.testUrl),
    );
  }
}

class _LineList extends ConsumerWidget {
  final String groupName;
  final String? testUrl;

  const _LineList({required this.groupName, required this.testUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(
      groupsProvider.select(
        (state) =>
            state.getGroup(groupName)?.all.map((e) => e.name).toList() ??
            const <String>[],
      ),
    );
    final selected = ref.watch(selectedProxyNameProvider(groupName));
    final rows = buildTianjiLineRows(
      members: members,
      selectedName: selected,
      resolveReal: (name) =>
          ref.read(realSelectedProxyStateProvider(name)).proxyName,
    );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(tjGap4, tjGap3, tjGap4, tjGap5),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: tjGap2),
      itemBuilder: (_, i) => TianjiStagger(
        index: i,
        child: _LineTile(row: rows[i], groupName: groupName, testUrl: testUrl),
      ),
    );
  }
}

/// 行首的圆形徽章。
///
/// 🔴 徽章的绿勾表示「这条线路这一轮测通了」，**不能**给没测过的线路也画绿勾 ——
///    那是把「不知道」说成「可用」（红线 5）。没结论的画成中性圈。
class _Badge extends StatelessWidget {
  final IconData icon;
  final Color fg;
  final Color bg;
  const _Badge({required this.icon, required this.fg, required this.bg});

  // 切线路时徽章从中性圈变成实心勾：渐变过去，不跳变
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: tjNormal,
    curve: tjCurve,
    width: 26,
    height: 26,
    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
    child: AnimatedSwitcher(
      duration: tjFast,
      child: Icon(icon, key: ValueKey(icon), size: 16, color: fg),
    ),
  );
}

class _LineTile extends ConsumerWidget {
  final TianjiLineRow row;
  final String groupName;
  final String? testUrl;

  const _LineTile({
    required this.row,
    required this.groupName,
    required this.testUrl,
  });

  /// 切线路：改内核的选择、记进当前配置（重启后还在）、刷新分组显示。
  Future<void> _select(WidgetRef ref) async {
    await ref
        .read(proxiesActionProvider.notifier)
        .changeProxy(groupName: groupName, proxyName: row.name);
    ref
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap(groupName, row.name);
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
  }

  String _delayText(BuildContext context, int? delay) {
    if (delay == null || delay == 0) return '';
    if (delay < 0) return context.appLocalizations.tianjiTimeout;
    return '$delay ms';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final tj = context.tj;
    final accent = context.colorScheme.primary;
    final delay = row.locked
        ? null
        : ref.watch(delayProvider(proxyName: row.name, testUrl: testUrl));
    final dot = row.locked ? tj.unknown : utils.getDelayColor(delay);
    final delayText = _delayText(context, delay);
    final measured = delay != null && delay > 0;

    // 副标题就是设计稿那一行「香港 · 01 · 48 ms」：落地名与延迟拼在一起。
    final parts = <String>[
      if (row.locked)
        l.tianjiLocked
      else if (row.showsReal)
        tianjiBaseAlias(row.realName),
      if (delayText.isNotEmpty) delayText,
    ];

    final Widget badge;
    if (row.locked) {
      badge = _Badge(
        icon: Icons.lock_outline,
        fg: tj.ink3,
        bg: tj.unknown.withValues(alpha: 0.14),
      );
    } else if (row.selected) {
      badge = _Badge(icon: Icons.check, fg: Colors.white, bg: accent);
    } else if (measured) {
      badge = _Badge(
        icon: Icons.check,
        fg: tj.good,
        bg: tj.good.withValues(alpha: 0.14),
      );
    } else {
      badge = _Badge(
        icon: Icons.circle_outlined,
        fg: tj.ink3,
        bg: tj.unknown.withValues(alpha: 0.12),
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(tjRadiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(tjRadiusCard),
        onTap: row.locked
            ? () => globalState.openUrl(
                '${ref.read(tianjiSettingProvider).apiBase}/#/plan',
              )
            : () => _select(ref),
        // 🔴 选中态整行渐变：点一下线路，底色与描边 280ms 淌过去。
        //    跳变会让人怀疑「我点中了吗」——切线路是这一页唯一的操作，
        //    它必须给出明确的答复。
        child: AnimatedContainer(
          duration: tjNormal,
          curve: tjCurve,
          decoration: BoxDecoration(
            color: row.selected ? accent.withValues(alpha: 0.08) : tj.card,
            borderRadius: BorderRadius.circular(tjRadiusCard),
            border: Border.all(
              color: row.selected ? accent.withValues(alpha: 0.55) : tj.line,
              width: row.selected ? 1.4 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: tjGap3,
              vertical: tjGap3,
            ),
            child: Row(
              children: [
                badge,
                const SizedBox(width: tjGap3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tianjiBaseAlias(row.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: row.locked ? tj.ink2 : null,
                        ),
                      ),
                      if (parts.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          parts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: tj.ink3,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: tjGap2),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: dot ?? tj.unknown,
                    shape: BoxShape.circle,
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
