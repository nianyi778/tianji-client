import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/views.dart';
import 'package:flutter/material.dart';

class Navigation {
  static Navigation? _instance;

  /// [developerMode] 为假时，上游那几个面向高级用户的页整个不出现 ——
  /// 🔴 不是「挪到更多里」而是**不显示**：普通客户打开「更多」看到仪表盘、代理、配置
  /// 三个自己永远不会用的入口，只会怀疑自己是不是哪里没配好。
  /// 订阅跟账号绑、线路有「线路」页、状态有首页，这三项对他们没有任何用途。
  /// 需要时在「更多 → 专业模式」打开，它们立刻回来。
  List<NavigationItem> getItems({
    bool openLogs = false,
    bool hasProxies = false,
    bool developerMode = false,
  }) {
    return [
      NavigationItem(
        icon: const Icon(Icons.home_outlined),
        label: PageLabel.home,
        builder: (_) =>
            const TianjiHomeView(key: GlobalObjectKey(PageLabel.home)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      NavigationItem(
        icon: const Icon(Icons.alt_route),
        label: PageLabel.lines,
        builder: (_) =>
            const TianjiLinesView(key: GlobalObjectKey(PageLabel.lines)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      // 设计稿里底部是五格：首页｜线路｜AI 加速｜诊断｜我的，AI 夹在正中间 ——
      // 它是第一卖点，放中间那格是刻意的。
      NavigationItem(
        icon: const Icon(Icons.auto_awesome_outlined),
        label: PageLabel.ai,
        builder: (_) => const TianjiAiView(key: GlobalObjectKey(PageLabel.ai)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      NavigationItem(
        icon: const Icon(Icons.health_and_safety_outlined),
        label: PageLabel.diagnosis,
        builder: (_) => const TianjiDiagnosisView(
          key: GlobalObjectKey(PageLabel.diagnosis),
        ),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      NavigationItem(
        icon: const Icon(Icons.person_outline),
        label: PageLabel.mine,
        builder: (_) =>
            const TianjiAccountView(key: GlobalObjectKey(PageLabel.mine)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
      // 首页已经给出连接状态、当前线路与速率；FlClash 的仪表盘九宫格退到「更多」
      NavigationItem(
        keep: false,
        icon: const Icon(Icons.space_dashboard),
        label: PageLabel.dashboard,
        builder: (_) =>
            const DashboardView(key: GlobalObjectKey(PageLabel.dashboard)),
        modes: developerMode ? [NavigationItemMode.more] : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.article),
        label: PageLabel.proxies,
        builder: (_) =>
            const ProxiesView(key: GlobalObjectKey(PageLabel.proxies)),
        // 天机的「线路」页取代了它；完整的分组/节点视图退到「更多」
        modes: (hasProxies && developerMode) ? [NavigationItemMode.more] : [],
      ),
      // 🔴 订阅跟账号绑定，登录时自动拉、自动更新 —— 普通用户不该管它。
      //    但不能删：选了「手动导入订阅」的人要靠它。退到「更多」。
      NavigationItem(
        icon: const Icon(Icons.folder),
        label: PageLabel.profiles,
        builder: (_) =>
            const ProfilesView(key: GlobalObjectKey(PageLabel.profiles)),
        // 🔴 手动导入订阅的人要靠它，所以专业模式下必须能找回来
        modes: developerMode ? [NavigationItemMode.more] : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.view_timeline),
        label: PageLabel.requests,
        builder: (_) =>
            const RequestsView(key: GlobalObjectKey(PageLabel.requests)),
        description: 'requestsDesc',
        modes: developerMode ? [NavigationItemMode.more] : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.ballot),
        label: PageLabel.connections,
        builder: (_) =>
            const ConnectionsView(key: GlobalObjectKey(PageLabel.connections)),
        description: 'connectionsDesc',
        modes: developerMode ? [NavigationItemMode.more] : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.storage),
        label: PageLabel.resources,
        description: 'resourcesDesc',
        builder: (_) =>
            const ResourcesView(key: GlobalObjectKey(PageLabel.resources)),
        modes: developerMode ? [NavigationItemMode.more] : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.adb),
        label: PageLabel.logs,
        builder: (_) => const LogsView(key: GlobalObjectKey(PageLabel.logs)),
        description: 'logsDesc',
        modes: openLogs
            ? [NavigationItemMode.desktop, NavigationItemMode.more]
            : [],
      ),
      NavigationItem(
        icon: const Icon(Icons.construction),
        label: PageLabel.tools,
        builder: (_) => const ToolsView(key: GlobalObjectKey(PageLabel.tools)),
        modes: [NavigationItemMode.desktop, NavigationItemMode.mobile],
      ),
    ];
  }

  Navigation._internal();

  factory Navigation() {
    _instance ??= Navigation._internal();
    return _instance!;
  }
}

final navigation = Navigation();
