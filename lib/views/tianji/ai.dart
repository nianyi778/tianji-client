import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AI 加速页：给每个 AI 服务单独指一条线路。
///
/// 为什么需要它：同一条线对 ChatGPT 好用、对 Claude 被拦是常事（状态页每轮实测
/// 都能看到）。以前客户只能整体换线，换完别的又坏了。
///
/// 🔴 这一页的开关**落在订阅模板的 `🤖 xxx` 分组上**，不是我们自己发明的状态。
///    客户拿到的订阅里没有这些组时（老订阅、或模板还没推），这一页必须
///    **优雅地说明原因 + 给一个能点的动作**，而不是显示一个空列表 ——
///    空列表看起来像功能坏了，而它只是还没更新订阅。
///
/// 🔴 每个服务的「可用 / 不可用」来自状态页的公开实测，取不到就是「暂时无法获取」，
///    绝不画成红点（红线 4：把自己的取数失败报成线路故障会引发退款潮）。
class TianjiAiView extends ConsumerWidget {
  const TianjiAiView({super.key});

  /// 模板里这四个组的名字。🔴 与 `deploy/xboard-templates/clashmeta.yaml`
  ///    里的组名必须逐字一致 —— 差一个空格这一页就永远是空的，而且不会报错。
  static const groupNames = [
    '🤖 ChatGPT',
    '🤖 Claude',
    '🤖 Gemini',
    '🤖 Perplexity',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final groups = ref.watch(groupsProvider);
    final present = groupNames
        .where((n) => groups.any((g) => g.name == n))
        .toList();

    return CommonScaffold(
      title: l.tianjiAiBoost,
      body: present.isEmpty
          ? const _NoGroups()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                tjGap4,
                tjGap3,
                tjGap4,
                tjGap5,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: tjGap3),
                  child: Text(
                    l.tianjiAiBoostDesc,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.tj.ink3,
                    ),
                  ),
                ),
                for (var i = 0; i < present.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: tjGap2),
                    // 逐项淡入上移：四张卡一起出现会显得生硬，错开 60ms 有节奏
                    child: _Stagger(
                      index: i,
                      child: _ServiceCard(groupName: present[i]),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 入场：淡入 + 上移 10px，按序号错开。只在第一次构建时跑一次。
class _Stagger extends StatefulWidget {
  final int index;
  final Widget child;
  const _Stagger({required this.index, required this.child});

  @override
  State<_Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<_Stagger> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    // 🔴 用 postFrame 而不是 Timer：Timer 在 widget 测试里会留下
    //    「A Timer is still pending」把整棵树弄红（2026-09-30 踩过）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: Offset(0, (1 - _t) * 0.06),
    duration: Duration(milliseconds: 320 + widget.index * 60),
    curve: Curves.easeOutCubic,
    child: AnimatedOpacity(
      opacity: _t,
      duration: Duration(milliseconds: 280 + widget.index * 60),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// 订阅里没有 AI 分组时的样子。说清楚原因，给一个能点的动作。
class _NoGroups extends ConsumerWidget {
  const _NoGroups();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final tj = context.tj;
    final profile = ref.watch(currentProfileProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(tjGap6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 44, color: tj.ink3),
            const SizedBox(height: tjGap4),
            Text(
              l.tianjiAiNoGroups,
              textAlign: TextAlign.center,
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: tjGap2),
            Text(
              l.tianjiAiNoGroupsDesc,
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(color: tj.ink3),
            ),
            if (profile != null) ...[
              const SizedBox(height: tjGap5),
              FilledButton.icon(
                onPressed: () => ref
                    .read(profilesActionProvider.notifier)
                    .updateProfile(profile, showLoading: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.tianjiUpdateSub),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  final String groupName;
  const _ServiceCard({required this.groupName});

  /// 组名去掉 🤖 前缀就是服务名，正好对上状态页的 service 名。
  String get service => groupName.replaceFirst('🤖 ', '');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final tj = context.tj;
    final selected = ref.watch(selectedProxyNameProvider(groupName));
    final real = ref.watch(realSelectedProxyStateProvider(groupName));
    final status = ref.watch(tianjiAiStatusStateProvider);
    final state = status?.forNode(real.proxyName)?[service];

    // 🔴 选中主组时说「跟随主线路」，而不是把主组的名字原样显示 ——
    //    「$app_name」对客户没有意义，而「跟随主线路」说清了这就是默认。
    final following = selected == null || selected.startsWith(r'$');
    final lineText = following
        ? l.tianjiAiFollowMain
        : tianjiBaseAlias(real.proxyName.isEmpty ? selected : real.proxyName);

    final (Color dot, String word) = state == null
        ? (tj.unknown, status == null ? l.tianjiAiNoData : l.tianjiAiNotProbed)
        : state.state == 'unknown'
        ? (tj.unknown, l.tianjiAiUnknown)
        : state.available
        ? (tj.good, l.tianjiAiAvailable)
        : (tj.bad, l.tianjiAiOffline);

    return Material(
      color: tj.card,
      borderRadius: BorderRadius.circular(tjRadiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(tjRadiusCard),
        onTap: () => _pick(context, ref),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tjRadiusCard),
            border: Border.all(color: tj.line),
          ),
          child: Padding(
            padding: const EdgeInsets.all(tjGap4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: tjGap2),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: tjGap2),
                    // 🔴 判语要能缩：别的语言下「暂时无法获取」会更长
                    Flexible(
                      child: Text(
                        word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: dot,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: tjGap3),
                Row(
                  children: [
                    Icon(Icons.alt_route, size: 15, color: tj.ink3),
                    const SizedBox(width: tjGap2),
                    Expanded(
                      child: Text(
                        lineText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: following ? tj.ink3 : tj.ink2,
                          fontWeight: following
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: tj.ink3),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final groups = ref.read(groupsProvider);
    final i = groups.indexWhere((g) => g.name == groupName);
    if (i < 0 || groups[i].all.isEmpty) return;
    final members = groups[i].all;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PickSheet(groupName: groupName, members: members),
    );
    if (picked == null) return;
    await ref
        .read(proxiesActionProvider.notifier)
        .changeProxy(groupName: groupName, proxyName: picked);
    ref
        .read(profilesActionProvider.notifier)
        .updateCurrentSelectedMap(groupName, picked);
    ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
  }
}

class _PickSheet extends ConsumerWidget {
  final String groupName;
  final List<Proxy> members;
  const _PickSheet({required this.groupName, required this.members});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final tj = context.tj;
    final selected = ref.watch(selectedProxyNameProvider(groupName));
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(tjGap5, 0, tjGap5, tjGap3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.tianjiPickLine,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(tjGap3, 0, tjGap3, tjGap4),
              itemCount: members.length,
              itemBuilder: (context, i) {
                final name = members[i].name;
                final isMain = name.startsWith(r'$');
                final on = selected == name;
                return ListTile(
                  dense: true,
                  selected: on,
                  selectedTileColor: context.colorScheme.primary.withValues(
                    alpha: 0.08,
                  ),
                  leading: Icon(
                    on ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20,
                    color: on ? context.colorScheme.primary : tj.ink3,
                  ),
                  title: Text(
                    isMain ? l.tianjiAiFollowMain : tianjiBaseAlias(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
