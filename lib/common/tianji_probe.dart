/// 诊断页的判定逻辑 —— 纯函数，test/tianji_probe_test.dart 钉着。
///
/// 🔴 探测目标与判定规则**逐条对齐 checker/internal/probe/probe.go**。
///    状态页上那套结论是客户买之前看到的，App 里再测一遍如果用另一套规则，
///    两边会对同一条线路给出相反答案 —— 而我们卖的正是「实测可信」。
///    改这里之前先改 checker，或者反过来，但两边必须一起改。
///
/// 🔴 测不出来 ≠ 不可用。超时、TLS 失败、连接被拒、看不懂的状态码，一律 unknown。
library;

enum TianjiProbeState { available, unavailable, unknown }

/// 浏览器 UA。不带它很多站直接给机器人质询，那测的就不是线路了。
const tianjiProbeUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/122.0 Safari/537.36';

class TianjiProbeTarget {
  final String service;
  final String url;

  /// 判为「可用」的状态码。空则 2xx。
  final List<int> okStatus;

  /// 响应体里出现这个子串即判「不可用」（地区封锁的典型响应）。
  final String blockedBody;

  /// 出现这些状态码即判「不可用」。
  final List<int> blockedStatus;

  const TianjiProbeTarget({
    required this.service,
    required this.url,
    this.okStatus = const [],
    this.blockedBody = '',
    this.blockedStatus = const [],
  });
}

/// 🔴 必须打 /cdn-cgi/trace，不能打首页：这些站在 Cloudflare 后面，
///    首页对任何没有浏览器指纹的 HTTP 客户端一律 403，那是机器人质询，与线路无关。
const tianjiAiTargets = <TianjiProbeTarget>[
  TianjiProbeTarget(
    service: 'ChatGPT',
    url: 'https://chatgpt.com/cdn-cgi/trace',
    blockedBody: 'loc=CN',
    blockedStatus: [403],
  ),
  TianjiProbeTarget(
    service: 'Claude',
    url: 'https://claude.ai/cdn-cgi/trace',
    blockedStatus: [403],
  ),
  TianjiProbeTarget(
    service: 'Gemini',
    url: 'https://gemini.google.com/',
    blockedStatus: [403, 451],
  ),
  TianjiProbeTarget(
    service: 'Perplexity',
    url: 'https://www.perplexity.ai/cdn-cgi/trace',
    blockedBody: 'loc=CN',
    blockedStatus: [403],
  ),
];

/// [statusCode] 为 null 表示请求根本没成功（超时 / TLS / 连接被拒）。
TianjiProbeState classifyTianjiProbe({
  required TianjiProbeTarget target,
  required int? statusCode,
  required String body,
}) {
  if (statusCode == null) return TianjiProbeState.unknown;
  if (target.blockedStatus.contains(statusCode)) {
    return TianjiProbeState.unavailable;
  }
  if (target.blockedBody.isNotEmpty && body.contains(target.blockedBody)) {
    return TianjiProbeState.unavailable;
  }
  if (target.okStatus.isNotEmpty) {
    return target.okStatus.contains(statusCode)
        ? TianjiProbeState.available
        : TianjiProbeState.unknown;
  }
  if (statusCode >= 200 && statusCode < 300) return TianjiProbeState.available;
  // 3xx / 5xx / 其他 —— 说不清
  return TianjiProbeState.unknown;
}

/// 出口地址是不是 IPv6。🔴 这是 Claude 频繁弹验证最常见的单一原因。
bool tianjiIsIpv6(String ip) => ip.contains(':');

enum TianjiCheckLevel { ok, warn, bad, unknown }

/// 诊断给出的那一句结论，以及它建议做的那一件事。
class TianjiVerdict {
  final TianjiCheckLevel level;

  /// 结论的语义标识，页面拿它取本地化文案
  final String code;

  /// 需要点名的服务（code 为 aiDown 时非空）
  final List<String> services;

  /// 建议切过去的线路；null 表示没有更好的可选项
  final String? suggestedLine;

  const TianjiVerdict({
    required this.level,
    required this.code,
    this.services = const [],
    this.suggestedLine,
  });
}

/// 结论优先级：没连上 → 测不出 → 有服务不可用 → IPv6 出口 → 部分测不出 → 正常。
///
/// 🔴 「有服务不可用」排在「IPv6 出口」前面，但文案里要带上 IPv6 ——
///    IPv6 通常就是那个不可用的成因，只报现象不报成因，用户会换一堆线路瞎试。
TianjiVerdict tianjiVerdict({
  required bool running,
  required String? exitIp,
  required Map<String, TianjiProbeState> ai,
  String? suggestedLine,
}) {
  if (!running) {
    return const TianjiVerdict(
      level: TianjiCheckLevel.unknown,
      code: 'notRunning',
    );
  }
  if (exitIp == null || exitIp.isEmpty) {
    return const TianjiVerdict(level: TianjiCheckLevel.unknown, code: 'noExit');
  }
  final ipv6 = tianjiIsIpv6(exitIp);
  final down = ai.entries
      .where((e) => e.value == TianjiProbeState.unavailable)
      .map((e) => e.key)
      .toList();
  if (down.isNotEmpty) {
    return TianjiVerdict(
      level: TianjiCheckLevel.bad,
      code: ipv6 ? 'aiDownIpv6' : 'aiDown',
      services: down,
      suggestedLine: suggestedLine,
    );
  }
  if (ipv6) {
    return TianjiVerdict(
      level: TianjiCheckLevel.warn,
      code: 'ipv6',
      suggestedLine: suggestedLine,
    );
  }
  if (ai.values.any((v) => v == TianjiProbeState.unknown)) {
    return const TianjiVerdict(
      level: TianjiCheckLevel.warn,
      code: 'partialUnknown',
    );
  }
  return const TianjiVerdict(level: TianjiCheckLevel.ok, code: 'allGood');
}
