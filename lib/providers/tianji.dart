import 'dart:async';
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
Dio tianjiDio() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      validateStatus: (_) => true,
      headers: {'User-Agent': globalState.ua},
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

/// 状态页的公开实测数据，每分钟拉一次。拉不到就保持上一份，从来没拉到过就是 null。
/// 🔴 拉不到 ≠ 全部不可用：首页对 null 显示「暂时无法获取」，不画红点（红线 4 / 6）。
@Riverpod(keepAlive: true)
class TianjiAiStatusState extends _$TianjiAiStatusState {
  Timer? _timer;
  bool _busy = false;
  int? _failedAt;

  @override
  TianjiAiStatus? build() {
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(refresh);
    return null;
  }

  /// 最近一次拉取失败的时间（秒），首页用来在数据过旧时说明「上次更新于」。
  int? get failedAt => _failedAt;

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final res = await tianjiDio().get('$tianjiStatusUrl/api/ai-status');
      final parsed = res.statusCode == 200
          ? TianjiAiStatus.parse(res.data)
          : null;
      if (parsed != null) {
        state = parsed;
        _failedAt = null;
      } else {
        _failedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      }
    } catch (e) {
      _failedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
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
