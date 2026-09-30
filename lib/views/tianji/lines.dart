import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/common.dart';
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
                  color: context.colorScheme.onSurfaceVariant,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) =>
          _LineTile(row: rows[i], groupName: groupName, testUrl: testUrl),
    );
  }
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
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final delay = row.locked
        ? null
        : ref.watch(delayProvider(proxyName: row.name, testUrl: testUrl));
    final dot = row.locked
        ? colorScheme.outlineVariant
        : utils.getDelayColor(delay);
    final text = _delayText(context, delay);
    return Material(
      color: row.selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: row.locked
            ? () => globalState.openUrl(
                '${ref.read(tianjiSettingProvider).apiBase}/#/plan',
              )
            : () => _select(ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                row.locked
                    ? Icons.lock_outline
                    : row.selected
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                size: 20,
                color: row.locked
                    ? colorScheme.onSurfaceVariant
                    : row.selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tianjiBaseAlias(row.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: row.locked ? colorScheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (row.locked || row.showsReal) ...[
                      const SizedBox(height: 2),
                      Text(
                        row.locked
                            ? appLocalizations.tianjiLocked
                            : tianjiBaseAlias(row.realName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (text.isNotEmpty) ...[
                Text(
                  text,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: dot ?? colorScheme.outlineVariant,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
