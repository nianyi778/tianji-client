import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/tianji.g.dart';

/// 天机专用 HTTP 客户端：
/// - 走上游同一套 findProxy（内核在跑就经本地代理，没跑就直连）；
/// - 🔴 不接受坏证书。上游的 HttpOverrides 对所有请求都 `badCertificateCallback = true`，
///   账号密码和公开数据这两条路都必须验证书。
String _ua() {
  try {
    return globalState.ua;
  } catch (_) {
    return browserUa;
  }
}

Dio tianjiDio() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      // globalState.ua 在 app 初始化完成前会抛 LateInitializationError
      headers: {'User-Agent': _ua()},
    ),
  );
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.badCertificateCallback = (_, _, _) => false;
      client.findProxy = FlClashHttpOverrides.handleFindProxy;
      return client;
    },
  );
  return dio;
}

/// TianjiNodeTags 给「够全解锁」的节点名加的后缀；状态页的 alias 不带它。
const tianjiFullUnlockSuffix = ' · 🎬🤖 全解锁';

String tianjiBaseAlias(String name) =>
    name.replaceAll(tianjiFullUnlockSuffix, '').trim();

/// 状态页 /api/ai-status 里一个服务在一个节点上的实测结论。
/// state 是 available / unknown / offline 原样透传 —— 🔴 unknown 是「没测出结论」，不是「不可用」。
class TianjiAiServiceState {
  final String state;
  final bool overridden;
  final int? since;

  const TianjiAiServiceState({
    required this.state,
    this.overridden = false,
    this.since,
  });

  bool get available => state == 'available';
  bool get offline => state == 'offline';
}

class TianjiAiStatus {
  final int generatedAt;
  final List<String> services;
  final Map<String, Map<String, TianjiAiServiceState>> nodes;

  const TianjiAiStatus({
    required this.generatedAt,
    required this.services,
    required this.nodes,
  });

  Map<String, TianjiAiServiceState>? forNode(String name) =>
      nodes[tianjiBaseAlias(name)];

  static TianjiAiStatus? parse(Object? body) {
    if (body is! Map || body['ok'] != true || body['nodes'] is! List) {
      return null;
    }
    final services =
        (body['services'] as List?)?.whereType<String>().toList() ??
        const ['ChatGPT', 'Claude', 'Gemini', 'Perplexity'];
    final nodes = <String, Map<String, TianjiAiServiceState>>{};
    for (final n in body['nodes'] as List) {
      if (n is! Map || n['alias'] is! String || n['services'] is! Map) {
        continue;
      }
      final m = <String, TianjiAiServiceState>{};
      (n['services'] as Map).forEach((k, v) {
        if (k is String && v is Map && v['state'] is String) {
          m[k] = TianjiAiServiceState(
            state: v['state'] as String,
            overridden: v['overridden'] == true,
            since: v['since'] is int ? v['since'] as int : null,
          );
        }
      });
      nodes[n['alias'] as String] = m;
    }
    return TianjiAiStatus(
      generatedAt: body['generated_at'] is int
          ? body['generated_at'] as int
          : 0,
      services: services,
      nodes: nodes,
    );
  }
}

/// 状态页的公开实测数据。按需拉取：首页每次显示时看一眼，超过 [_staleAfter] 就重拉。
///
/// 🔴 不用后台定时器。定时器在 App 空闲或退到后台时照样打请求（每人每天上千次，
///    换不来任何用户能察觉的新鲜度），而且在 widget 测试里会以
///    「A Timer is still pending even after the widget tree was disposed」
///    把整棵树的测试弄红 —— 2026-09-30 就是这么发现的。
/// 🔴 拉不到就保持上一份；从来没拉到过就是 null。首页对 null 显示「暂时无法获取」，
///    不画红点 —— 把自己的取数失败报成线路故障会引发退款潮（红线 4 / 6）。
@Riverpod(keepAlive: true)
class TianjiAiStatusState extends _$TianjiAiStatusState {
  static const _staleAfter = Duration(minutes: 5);

  bool _busy = false;
  DateTime? _lastTry;

  @override
  TianjiAiStatus? build() => null;

  /// 上次尝试是否失败了（首页据此说明数据是旧的）
  bool get lastTryFailed => _lastTryFailed;
  bool _lastTryFailed = false;

  Future<void> refreshIfStale() async {
    final last = _lastTry;
    if (last != null && DateTime.now().difference(last) < _staleAfter) return;
    await refresh();
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    _lastTry = DateTime.now();
    try {
      final res = await tianjiDio().get('$tianjiStatusUrl/api/ai-status');
      final parsed = res.statusCode == 200
          ? TianjiAiStatus.parse(res.data)
          : null;
      if (parsed != null) {
        state = parsed;
        _lastTryFailed = false;
      } else {
        _lastTryFailed = true;
      }
    } catch (e) {
      _lastTryFailed = true;
      commonPrint.log(
        'tianji ai-status failed: $e',
        logLevel: LogLevel.warning,
      );
    } finally {
      _busy = false;
    }
  }
}

/// 订阅模板里的主分组：第一个不是 GLOBAL、成员多于 1 的 select 组（天机模板里叫「天机 TIANJI」）。
@riverpod
Group? tianjiMainGroup(Ref ref) {
  final groups = ref.watch(groupsProvider);
  return groups.firstWhereOrNull(
    (g) =>
        g.type == GroupType.Selector && g.name != 'GLOBAL' && g.all.length > 1,
  );
}

/// Xboard 的公开配置（`guest/comm/config`）。只取我们要用的几项。
///
/// 🔴 这些值后台随时能改，**不许在客户端写死**（CLAUDE.md 第一条）。
///    取不到就返回 null，界面上对应的项整个不显示，绝不回落到写死的地址。
class TianjiPublicConfig {
  final String? telegramLink;
  final String? telegramBot;

  const TianjiPublicConfig({this.telegramLink, this.telegramBot});

  static TianjiPublicConfig? parse(Object? body) {
    if (body is! Map || body['data'] is! Map) return null;
    final d = body['data'] as Map;
    String? str(String k) {
      final v = d[k];
      return v is String && v.isNotEmpty ? v : null;
    }

    return TianjiPublicConfig(
      telegramLink: str('telegram_discuss_link'),
      telegramBot: str('telegram_bot_username'),
    );
  }
}

/// 拉一次公开配置，结果缓存在 provider 里。失败返回 null。
@Riverpod(keepAlive: true)
Future<TianjiPublicConfig?> tianjiPublicConfig(Ref ref) async {
  final base = ref
      .watch(tianjiSettingProvider)
      .apiBase
      .trim()
      .replaceAll(RegExp(r'/+$'), '');
  try {
    final res = await tianjiDio().get('$base/api/v1/guest/comm/config');
    if (res.statusCode != 200) return null;
    return TianjiPublicConfig.parse(res.data);
  } catch (e) {
    commonPrint.log('tianji public config failed: $e', logLevel: LogLevel.info);
    return null;
  }
}
