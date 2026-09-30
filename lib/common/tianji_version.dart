/// 版本比较 —— 纯函数，test/tianji_version_test.dart 钉着。
///
/// 🔴 上游的 `utils.compareVersions` 见到我们的 tag `v0.8.96-tianji.7` 会在
///    `int.parse('96-tianji')` 上抛异常，而 `checkForUpdate` 把异常吞掉返回 null ——
///    更新检查会**静默失效**，没有任何症状。所以先剥掉 `-后缀` 再比，且自己不抛。
library;

/// `v0.8.96-tianji.7` → `0.8.96`；`0.8.96+2026081701` → `0.8.96`
String tianjiBaseVersion(String v) {
  var s = v.trim();
  if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
  s = s.split('+').first;
  s = s.split('-').first;
  return s;
}

List<int> _parts(String v) {
  final out = <int>[];
  for (final p in tianjiBaseVersion(v).split('.')) {
    out.add(int.tryParse(p) ?? 0);
  }
  while (out.length < 3) {
    out.add(0);
  }
  return out;
}

/// 远端发布是否比本机新。看不懂的版本号一律当作「没有更新」，不骚扰用户。
///
/// 🔴 代价说清楚：只打 `-tianji.N` 的 tag **不会**触发更新提示，
///    要让老用户收到提示必须同时 bump pubspec 里的 `version:`。
bool tianjiHasNewerRelease({
  required String remoteTag,
  required String localVersion,
}) {
  final r = _parts(remoteTag);
  final l = _parts(localVersion);
  for (var i = 0; i < 3; i++) {
    if (r[i] != l[i]) return r[i] > l[i];
  }
  return false;
}
