import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络变化事件要不要触发「自动优化」。纯函数，test/tianji_net_test.dart 钉着。
///
/// - 自己开关 VPN 会产生 [wifi] ↔ [wifi, vpn]：底层网络没变、只有 vpn 标志翻了 → 不优化
/// - 换 WiFi 时会再收到一次内容相同的 [wifi]（vpn 标志不变）→ 优化
/// - 断网（none / 空）→ 不优化，等下一次有网
class TianjiNetChange {
  final String sig;
  final bool hasVpn;
  final bool shouldOptimize;

  const TianjiNetChange(this.sig, this.hasVpn, this.shouldOptimize);
}

TianjiNetChange decideTianjiNetChange(
  List<ConnectivityResult> results, {
  required String? previousSig,
  required bool previousHasVpn,
}) {
  final hasVpn = results.contains(ConnectivityResult.vpn);
  final names =
      (results.toSet()..remove(ConnectivityResult.vpn))
          .map((e) => e.name)
          .toList()
        ..sort();
  final sig = names.join(',');
  final onlyVpnFlipped = sig == previousSig && hasVpn != previousHasVpn;
  final offline = sig.isEmpty || sig == ConnectivityResult.none.name;
  return TianjiNetChange(sig, hasVpn, !onlyVpnFlipped && !offline);
}
