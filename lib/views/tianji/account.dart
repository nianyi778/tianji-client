import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// 「我的」：账号、套餐、几个真正常用的开关。
///
/// 🔴 套餐名、流量额度、到期时间**全部来自 Xboard**（`getSubscribe`），
///    页面上不写死任何一个（CLAUDE.md 第一条）。取不到就整块不显示或写
///    「暂时无法获取」，绝不回落到好看的数字（红线 6）。
///
/// 🔴 这一页**不做支付**。「续费 / 升级」是一个跳到 web 面板的链接 ——
///    客户端里不出现价格、不出现套餐差异、不出现收银台，那些全在 Xboard 上，
///    抄一份进来就是等着和后台静默漂移。
class TianjiAccountView extends ConsumerWidget {
  const TianjiAccountView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final account = ref.watch(tianjiAccountProvider);
    final email = ref.watch(tianjiSettingProvider.select((s) => s.email));
    // 🔴 「没登录」和「取不到」是两件事。没登录时说「账号信息暂时无法获取」
    //    等于把一个正常状态报成故障 —— 客户会以为 app 坏了去开工单，
    //    而他只是还没登录。这里分开，并给一个能点的动作。
    final loggedIn = ref.watch(
      tianjiSettingProvider.select((s) => s.authData.isNotEmpty),
    );

    return CommonScaffold(
      title: l.tianjiMine,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(tianjiAccountProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(tjGap4, tjGap3, tjGap4, tjGap5),
          children: [
            _Header(email: email, account: account.value),
            const SizedBox(height: tjGap3),
            if (loggedIn) _PlanCard(account: account) else const _SignInCard(),
            const SizedBox(height: tjGap3),
            const _SettingsCard(),
            const SizedBox(height: tjGap5),
            Center(
              child: Text(
                _version(),
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.tj.ink3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 🔴 packageInfo 是 late，初始化完成前读它会抛 LateError。
String _version() {
  try {
    return 'v${globalState.packageInfo.version}';
  } catch (_) {
    return '';
  }
}

class _Header extends StatelessWidget {
  final String email;
  final TianjiAccount? account;
  const _Header({required this.email, required this.account});

  @override
  Widget build(BuildContext context) {
    final tj = context.tj;
    final accent = context.colorScheme.primary;
    final plan = account?.planName;
    return Container(
      padding: const EdgeInsets.all(tjGap4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tjRadiusCard),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(accent.withValues(alpha: 0.13), tj.card),
            tj.card,
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.person_outline, color: accent, size: 24),
          ),
          const SizedBox(width: tjGap3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔴 邮箱可以很长，必须能省略
                Text(
                  email.isEmpty ? '—' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (plan != null) ...[
                  const SizedBox(height: tjGap1),
                  _Badge(text: plan),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final accent = context.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: tjGap2, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tjRadiusPill),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  final AsyncValue<TianjiAccount?> account;
  const _PlanCard({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final tj = context.tj;
    final base = ref.watch(tianjiSettingProvider).apiBase;

    Widget shell(Widget child) => Container(
      padding: const EdgeInsets.all(tjGap4),
      decoration: BoxDecoration(
        color: tj.card,
        borderRadius: BorderRadius.circular(tjRadiusCard),
      ),
      child: child,
    );

    // 🔴 三种状态分得清清楚楚：加载中 / 取不到 / 拿到了。
    //    取不到时说「暂时无法获取」，不画一个 0 的进度条。
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: switch (account) {
        AsyncLoading() => shell(
          const SizedBox(
            height: 92,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ),
        AsyncData(value: final a?) => shell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.tianjiUsed,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (a.hasQuota)
                    Text(
                      '${tianjiBytes(a.used)} / ${tianjiBytes(a.total)}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: tj.ink2,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    )
                  else
                    Text(
                      tianjiBytes(a.used),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: tj.ink2,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              if (a.ratio != null) ...[
                const SizedBox(height: tjGap3),
                // 进度条从 0 长到实际值，不是啪一下就到位
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: a.ratio!),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(tjRadiusPill),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: tj.line,
                      // 用满了变红：这是客户最需要一眼看到的一件事
                      color: v >= 0.95 ? tj.bad : null,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: tjGap4),
              _Row(label: l.tianjiPlan, value: a.planName ?? l.tianjiNoPlan),
              _Row(label: l.tianjiExpireAt, value: _expiry(context, a)),
              if (a.resetDay != null)
                _Row(
                  // 这一行说的是「还有几天重置」，不是实时速率 ——
                  // 之前借用了 tianjiRealtimeTraffic，出来是「实时流量 12 天后重置」
                  label: l.tianjiTrafficReset,
                  value: l.tianjiResetIn(a.resetDay!),
                ),
              if (a.deviceLimit != null)
                _Row(
                  label: l.tianjiDevices,
                  value: l.tianjiDeviceUnit(a.deviceLimit!),
                ),
              const SizedBox(height: tjGap4),
              FilledButton.icon(
                onPressed: () => globalState.openUrl('$base/#/plan'),
                icon: const Icon(Icons.open_in_new, size: 17),
                label: Text(l.tianjiRenew),
              ),
            ],
          ),
        ),
        // 🔴 取不到（没登录 / 网络不通 / 接口变了）一律走这条 ——
        //    说实话，并且给一个能点的动作，不编数字。
        _ => shell(
          Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 20, color: tj.ink3),
              const SizedBox(width: tjGap3),
              Expanded(
                child: Text(
                  l.tianjiAccountFailed,
                  style: context.textTheme.bodySmall?.copyWith(color: tj.ink3),
                ),
              ),
              TextButton(
                onPressed: () => ref.invalidate(tianjiAccountProvider),
                child: Text(l.tianjiRetry),
              ),
            ],
          ),
        ),
      },
    );
  }

  String _expiry(BuildContext context, TianjiAccount a) {
    final l = context.appLocalizations;
    // 🔴 null 是「永久有效」，不是「未知」—— 免费档就是不过期的，
    //    显示成「未知」会让人以为出了问题
    if (a.expiredAt == null) return l.tianjiNeverExpire;
    if (a.expired) return l.tianjiExpired;
    return DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.fromMillisecondsSinceEpoch(a.expiredAt! * 1000));
  }
}

/// 没登录时的样子。不是错误态 —— 说清楚登录能看到什么，给一个按钮。
class _SignInCard extends ConsumerWidget {
  const _SignInCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final tj = context.tj;
    return Container(
      padding: const EdgeInsets.all(tjGap4),
      decoration: BoxDecoration(
        color: tj.card,
        borderRadius: BorderRadius.circular(tjRadiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.tianjiSignInPrompt,
            style: context.textTheme.bodySmall?.copyWith(color: tj.ink2),
          ),
          const SizedBox(height: tjGap4),
          FilledButton(
            onPressed: () => ref
                .read(tianjiSettingProvider.notifier)
                .update((s) => s.copyWith(skipLogin: false)),
            child: Text(l.tianjiSignIn),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.tj.ink3,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: context.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

class _SettingsCard extends ConsumerWidget {
  const _SettingsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.appLocalizations;
    final tj = context.tj;
    final auto = ref.watch(tianjiSettingProvider.select((s) => s.autoOptimize));
    final loggedIn = ref.watch(
      tianjiSettingProvider.select((s) => s.email.isNotEmpty),
    );

    // 🔴 这里必须是 Material 而不是带底色的 Container —— ListTile 把水波纹画在
    //    **最近的 Material 祖先**上，中间夹一层有底色的 DecoratedBox 会把它整个盖住：
    //    点下去没有任何反馈，而且 Flutter 只在 debug 下报一句断言，release 里悄无声息。
    return Material(
      color: tj.card,
      borderRadius: BorderRadius.circular(tjRadiusCard),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SwitchListTile(
            value: auto,
            onChanged: (v) => ref
                .read(tianjiSettingProvider.notifier)
                .update((s) => s.copyWith(autoOptimize: v)),
            title: Text(
              l.tianjiAutoOptimize,
              style: context.textTheme.bodyMedium,
            ),
            subtitle: Text(
              l.tianjiAutoOptimizeDesc,
              style: context.textTheme.bodySmall?.copyWith(color: tj.ink3),
            ),
            secondary: Icon(Icons.wifi_find_outlined, color: tj.ink2),
          ),
          Divider(height: 1, thickness: 1, color: tj.line, indent: tjGap4),
          ListTile(
            leading: Icon(Icons.build_outlined, color: tj.ink2),
            title: Text(l.tools, style: context.textTheme.bodyMedium),
            trailing: Icon(Icons.chevron_right, size: 18, color: tj.ink3),
            onTap: () => ref
                .read(currentPageLabelProvider.notifier)
                .toPage(PageLabel.tools),
          ),
          if (loggedIn) ...[
            Divider(height: 1, thickness: 1, color: tj.line, indent: tjGap4),
            ListTile(
              leading: Icon(Icons.logout, color: tj.bad),
              title: Text(
                l.tianjiLogout,
                style: context.textTheme.bodyMedium?.copyWith(color: tj.bad),
              ),
              onTap: () => _confirmLogout(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  /// 🔴 退出会**删掉订阅配置**，不是只清个登录态。必须先问一句 ——
  ///    误触的代价是客户要重新登录并等一次订阅下载。
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l = context.appLocalizations;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.tianjiLogout),
        content: Text(l.tianjiLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(tianjiActionProvider.notifier).logout();
  }
}
