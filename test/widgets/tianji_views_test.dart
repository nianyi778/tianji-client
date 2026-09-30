/// 线路页与诊断页的布局兜底。
///
/// 🔴 这两页的行都是「徽章 + 两行字 + 右侧判语」，中文之外的语言判语更长，
///    手机宽度下极容易溢出。溢出在 widget 测试里是会抛异常的，所以这里把两页
///    在最窄和最宽两种尺寸下都渲染一遍 —— 之前仪表盘的六处溢出全是这么逮到的。
library;

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/tianji/diagnosis.dart';
import 'package:fl_clash/views/tianji/account.dart';
import 'package:fl_clash/views/tianji/ai.dart';
import 'package:fl_clash/views/tianji/home.dart';
import 'package:fl_clash/views/tianji/lines.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _testUrl = 'https://example.invalid/generate_204';

/// 订阅模板里的四个 AI 组。每个的第一项是主组 —— 默认「跟随主线路」。
List<Group> _aiGroups() => const [
  Group(
    type: GroupType.Selector,
    name: '🤖 ChatGPT',
    now: r'$app_name',
    all: [
      Proxy(name: r'$app_name', type: 'Selector'),
      Proxy(name: '🇺🇸 洛杉矶 · 03', type: 'Hysteria2'),
    ],
  ),
  Group(
    type: GroupType.Selector,
    name: '🤖 Claude',
    now: '🇭🇰 香港 · 01',
    all: [
      Proxy(name: r'$app_name', type: 'Selector'),
      Proxy(name: '🇭🇰 香港 · 01', type: 'Shadowsocks'),
    ],
  ),
];

/// 一个像真订阅那样的主分组：选中项、测通的、超时的、没测过的、买不起的各一条。
List<Group> _groups() => const [
  Group(
    type: GroupType.Selector,
    name: '天机 TIANJI',
    testUrl: _testUrl,
    now: '🇭🇰 香港 · 01',
    all: [
      Proxy(name: '🇭🇰 香港 · 01', type: 'Shadowsocks'),
      Proxy(name: '🇭🇰 香港 · 02', type: 'Shadowsocks'),
      Proxy(name: '🇯🇵 东京 · 中转 B · 香港入口', type: 'Vless'),
      Proxy(name: '🇺🇸 洛杉矶 · 03', type: 'Hysteria2'),
      Proxy(name: '🔒 日本住宅', type: 'Shadowsocks'),
    ],
  ),
];

Map<String, Map<String, int>> _delays() => {
  _testUrl: {
    '🇭🇰 香港 · 01': 48,
    '🇭🇰 香港 · 02': 62,
    '🇯🇵 东京 · 中转 B · 香港入口': 112,
    '🇺🇸 洛杉矶 · 03': -1,
  },
};

/// 🔴 首页会在第一帧向状态页拉一次 AI 实测数据。测试里不该发真请求 ——
///    发了会留下一个挂着的 Timer，把整棵树的测试弄红，而且测的也不是布局。
class _TestAiStatus extends TianjiAiStatusState {
  @override
  TianjiAiStatus? build() => const TianjiAiStatus(
    generatedAt: 0,
    services: ['ChatGPT', 'Claude', 'Gemini', 'Perplexity'],
    nodes: {
      '香港 · 01': {
        'ChatGPT': TianjiAiServiceState(state: 'available'),
        'Claude': TianjiAiServiceState(state: 'available'),
        'Gemini': TianjiAiServiceState(state: 'unknown'),
        'Perplexity': TianjiAiServiceState(state: 'unavailable'),
      },
    },
  );

  @override
  Future<void> refreshIfStale() async {}

  @override
  Future<void> refresh() async {}
}

/// 一份带订阅用量的配置 —— 首页的流量条只有拿到真的 total 才会画出来。
class _TestProfiles extends Profiles {
  @override
  List<Profile> build() => const [
    Profile(
      id: 1,
      label: '天机 TIANJI',
      autoUpdateDuration: Duration(hours: 1),
      subscriptionInfo: SubscriptionInfo(
        upload: 12884901888,
        download: 137438953472,
        total: 1099511627776,
      ),
    ),
  ];
}

ProviderContainer _container({bool ai = false}) => ProviderContainer(
  overrides: [
    groupsProvider.overrideWithBuild(
      (_, _) => [..._groups(), if (ai) ..._aiGroups()],
    ),
    delayDataSourceProvider.overrideWithBuild((_, _) => _delays()),
    profilesProvider.overrideWith(_TestProfiles.new),
    currentProfileIdProvider.overrideWithBuild((_, _) => 1),
    tianjiAiStatusStateProvider.overrideWith(_TestAiStatus.new),
  ],
);

class _App extends StatelessWidget {
  final Widget child;

  /// 不指定就是 en —— 英文的判语比中文长，正好是布局最紧的一档。
  final Locale? locale;
  const _App({required this.child, this.locale});

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: globalState.navigatorKey,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.delegate.supportedLocales,
    home: child,
  );
}

void main() {
  final sizes = <String, Size>{
    // 还在卖的最窄的一批安卓机
    'phone': const Size(360, 740),
    'desktop': const Size(1280, 860),
  };

  for (final size in sizes.entries) {
    testWidgets('lines page lays out on ${size.key}', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = _container();
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = size.value;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _App(child: TianjiLinesView()),
        ),
      );
      await tester.pump();

      expect(find.text('🇭🇰 香港 · 01'), findsWidgets);
      expect(tester.takeException(), null);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('home dashboard lays out on ${size.key}', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = _container();
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = size.value;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _App(child: TianjiHomeView()),
        ),
      );
      await tester.pump();

      // 流量条只在拿到真的总量时出现
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // 快捷操作是桌面独有的
      expect(
        find.text('Quick actions'),
        size.key == 'desktop' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), null);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('AI page lays out on ${size.key}', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = _container(ai: true);
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = size.value;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _App(child: TianjiAiView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ChatGPT'), findsOneWidget);
      expect(find.text('Claude'), findsOneWidget);
      expect(tester.takeException(), null);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('account page lays out on ${size.key}', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = _container();
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = size.value;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _App(child: TianjiAccountView()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), null);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('diagnosis page lays out on ${size.key}', (tester) async {
      tester.view.physicalSize = size.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = _container();
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = size.value;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _App(child: TianjiDiagnosisView()),
        ),
      );
      await tester.pump();

      expect(find.text('DNS'), findsOneWidget);
      expect(tester.takeException(), null);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('🔴 订阅里没有 AI 分组时，给出原因和动作，而不是一个空列表', (tester) async {
    // 空列表看起来像功能坏了，而它只是订阅还没更新过。
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container(); // 不带 AI 组
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(360, 740);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _App(locale: Locale('zh', 'CN'), child: TianjiAiView()),
      ),
    );
    await tester.pump();

    expect(find.text('订阅里还没有 AI 分组'), findsOneWidget);
    expect(find.text('更新订阅'), findsOneWidget);
    expect(tester.takeException(), null);
  });

  testWidgets('🔴 AI 组选中主组时显示「跟随主线路」，不显示 \$app_name', (tester) async {
    // 「\$app_name」对客户没有任何意义 —— 它是模板里的占位符。
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container(ai: true);
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(360, 740);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _App(locale: Locale('zh', 'CN'), child: TianjiAiView()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('跟随主线路'), findsWidgets);
    expect(find.textContaining(r'$app_name'), findsNothing);
    expect(tester.takeException(), null);
  });

  testWidgets('🔴 AI 页最窄处服务名也不许被右侧判语挤到截断', (tester) async {
    // 踩过：判语用了 tianjiAiNotProbed（「这条线路不在公开实测范围内」）——
    // 那是一句话不是标签，它把整行撑满，反把服务名挤成「Chat···」，两样都读不了。
    // 客户是按「我要给 ChatGPT 换线」来用这一页的，名字截断就白做了。
    tester.view.physicalSize = const Size(320, 740); // 比最窄的在售机还窄
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container(ai: true);
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(320, 740);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _App(child: TianjiAiView()),
      ),
    );
    await tester.pumpAndSettle();

    for (final name in ['ChatGPT', 'Claude']) {
      final p = tester.renderObject<RenderParagraph>(find.text(name));
      expect(p.didExceedMaxLines, isFalse, reason: '「$name」被截断了');
    }
    expect(tester.takeException(), null);
  });

  testWidgets('🔴 买不起的那条线标成需升级，而不是标成故障', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _container();
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(viewSizeProvider.notifier).value = const Size(360, 740);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _App(locale: Locale('zh', 'CN'), child: TianjiLinesView()),
      ),
    );
    await tester.pump();

    expect(find.text('需升级套餐'), findsOneWidget);
    // 超时的那条写「超时」，不写成 0 ms
    expect(find.textContaining('超时'), findsOneWidget);
    expect(tester.takeException(), null);
  });
}
