// 截图工装：用**真实页面代码**渲染成 PNG，给运营方看效果。
//
// 不是测试，只是借 flutter test 的渲染环境。跑法：
//   TJ_SHOTS=<输出目录> TJ_FONT=<单体 CJK 字体> flutter test test/shots_test.dart
// 不带环境变量时整个文件跳过，所以它待在 test/ 里也不会拖慢 CI。
@Tags(['shots'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _testUrl = 'https://example.invalid/generate_204';

List<Group> _groups() => const [
  Group(
    type: GroupType.Selector,
    name: '天机 TIANJI',
    testUrl: _testUrl,
    now: '🇭🇰 香港 · 01',
    all: [
      Proxy(name: '🇭🇰 香港 · 01', type: 'Shadowsocks'),
      Proxy(name: '🇭🇰 香港 · 02', type: 'Shadowsocks'),
      Proxy(name: '🇯🇵 东京 · 01 · 中转 B · 香港入口', type: 'Vless'),
      Proxy(name: '🇺🇸 洛杉矶 · 03', type: 'Hysteria2'),
      Proxy(name: '🔒 日本住宅', type: 'Shadowsocks'),
    ],
  ),
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
    now: '🇺🇸 洛杉矶 · 03',
    all: [
      Proxy(name: r'$app_name', type: 'Selector'),
      Proxy(name: '🇺🇸 洛杉矶 · 03', type: 'Hysteria2'),
    ],
  ),
  Group(
    type: GroupType.Selector,
    name: '🤖 Gemini',
    now: r'$app_name',
    all: [Proxy(name: r'$app_name', type: 'Selector')],
  ),
  Group(
    type: GroupType.Selector,
    name: '🤖 Perplexity',
    now: r'$app_name',
    all: [Proxy(name: r'$app_name', type: 'Selector')],
  ),
];

Map<String, Map<String, int>> _delays() => {
  _testUrl: {
    '🇭🇰 香港 · 01': 48,
    '🇭🇰 香港 · 02': 62,
    '🇯🇵 东京 · 01 · 中转 B · 香港入口': 112,
    '🇺🇸 洛杉矶 · 03': 168,
  },
};

class _Profiles extends Profiles {
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

class _Setting extends TianjiSetting {
  @override
  TianjiProps build() => const TianjiProps(
    email: 'user@tianjiyun.org',
    authData: 'shots',
    apiBase: defaultTianjiApiBase,
  );
}

class _AiStatus extends TianjiAiStatusState {
  @override
  TianjiAiStatus? build() => const TianjiAiStatus(
    generatedAt: 0,
    services: ['ChatGPT', 'Claude', 'Gemini', 'Perplexity'],
    nodes: {
      '🇭🇰 香港 · 01': {
        'ChatGPT': TianjiAiServiceState(state: 'available'),
        'Claude': TianjiAiServiceState(state: 'available'),
        'Gemini': TianjiAiServiceState(state: 'unknown'),
        'Perplexity': TianjiAiServiceState(state: 'available'),
      },
      '🇺🇸 洛杉矶 · 03': {
        'ChatGPT': TianjiAiServiceState(state: 'available'),
        'Claude': TianjiAiServiceState(state: 'available'),
        'Gemini': TianjiAiServiceState(state: 'available'),
        'Perplexity': TianjiAiServiceState(state: 'available'),
      },
    },
  );

  @override
  Future<void> refreshIfStale() async {}
  @override
  Future<void> refresh() async {}
}

Future<void> _load(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
  await loader.load();
}

void main() {
  final dir = Platform.environment['TJ_SHOTS'];
  final font = Platform.environment['TJ_FONT'];
  if (dir == null) return;

  final cases = <String, (Widget, Size, bool)>{
    'phone-home': (const TianjiHomeView(), const Size(390, 844), false),
    'phone-lines': (const TianjiLinesView(), const Size(390, 844), false),
    'phone-ai': (const TianjiAiView(), const Size(390, 844), false),
    'phone-diagnosis': (
      const TianjiDiagnosisView(),
      const Size(390, 844),
      false,
    ),
    'phone-mine': (const TianjiAccountView(), const Size(390, 844), false),
    'phone-home-dark': (const TianjiHomeView(), const Size(390, 844), true),
    'phone-lines-dark': (const TianjiLinesView(), const Size(390, 844), true),
    'phone-ai-dark': (const TianjiAiView(), const Size(390, 844), true),
    'desktop-home': (const TianjiHomeView(), const Size(1280, 860), false),
    'desktop-home-dark': (const TianjiHomeView(), const Size(1280, 860), true),
    'desktop-lines': (const TianjiLinesView(), const Size(1280, 860), false),
  };

  setUpAll(() async {
    if (font != null) await _load('WQY', font);
    final emoji = Platform.environment['TJ_EMOJI'];
    if (emoji != null) await _load('Emoji', emoji);
    final icons = Platform.environment['TJ_ICONS'];
    // 图标字体在 flutter test 里默认没注册，不加载的话全是空方框
    if (icons != null) await _load('MaterialIcons', icons);
  });

  for (final e in cases.entries) {
    final (page, size, dark) = e.value;
    testWidgets('shot ${e.key}', (tester) async {
      // 🔴 physicalSize 是**物理像素**。给逻辑尺寸再设 dpr=2，实际渲染的是
      //    一半大小的屏（390×844 变成 195×422）—— 布局会走错分支，
      //    1280 宽的桌面稿会被当成手机渲染。必须乘上 dpr。
      const dpr = 2.0;
      tester.view.physicalSize = size * dpr;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          groupsProvider.overrideWithBuild((_, _) => _groups()),
          delayDataSourceProvider.overrideWithBuild((_, _) => _delays()),
          profilesProvider.overrideWith(_Profiles.new),
          currentProfileIdProvider.overrideWithBuild((_, _) => 1),
          tianjiAiStatusStateProvider.overrideWith(_AiStatus.new),
          tianjiAccountProvider.overrideWith(
            (_) async => const TianjiAccount(
              email: 'user@tianjiyun.org',
              planName: 'AI 住宅',
              expiredAt: 1798000000,
              used: 150323855360,
              total: 1099511627776,
              resetDay: 12,
              deviceLimit: 3,
            ),
          ),
          tianjiSettingProvider.overrideWith(_Setting.new),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = size;
      // isStart 是从 runTime 派生的：有开始时间就算在跑
      container.read(runTimeProvider.notifier).value = 3600;

      // ignore: avoid_print
      print('>> ${e.key} 开始');
      final key = GlobalKey();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('zh', 'CN'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.delegate.supportedLocales,
              theme: tianjiTheme(
                ThemeData(
                  useMaterial3: true,
                  fontFamily: font == null ? null : 'WQY',
                  fontFamilyFallback: const ['Emoji'],
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: const Color(defaultPrimaryColor),
                    brightness: dark ? Brightness.dark : Brightness.light,
                    // 🔴 必须和 app 一致（models/config.dart 的默认值）：
                    //    漏掉会退回 tonalSpot，主色被调得比真实的灰一大截，
                    //    看图会误判成"设计没还原"，而 app 本身是对的。
                    dynamicSchemeVariant: DynamicSchemeVariant.content,
                  ),
                ),
              ),
              home: page,
            ),
          ),
        ),
      );
      // ignore: avoid_print
      print('>> ${e.key} pumpWidget 完成');
      // 等入场动画走完
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 900));

      // ignore: avoid_print
      print('>> ${e.key} pump 完成，开始 toImage');
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: dpr);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/${e.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }
}
