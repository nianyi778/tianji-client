import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/common/tianji_net.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const wifi = ConnectivityResult.wifi;
  const vpn = ConnectivityResult.vpn;
  const none = ConnectivityResult.none;
  const mobile = ConnectivityResult.mobile;

  test('自己开 VPN：[wifi] → [wifi, vpn] 不优化', () {
    final d = decideTianjiNetChange(
      [wifi, vpn],
      previousSig: 'wifi',
      previousHasVpn: false,
    );
    expect(d.shouldOptimize, isFalse);
    expect(d.sig, 'wifi');
    expect(d.hasVpn, isTrue);
  });

  test('自己关 VPN：[wifi, vpn] → [wifi] 不优化', () {
    final d = decideTianjiNetChange(
      [wifi],
      previousSig: 'wifi',
      previousHasVpn: true,
    );
    expect(d.shouldOptimize, isFalse);
  });

  test('换 WiFi：内容相同的 [wifi, vpn] 再来一次 → 优化', () {
    final d = decideTianjiNetChange(
      [wifi, vpn],
      previousSig: 'wifi',
      previousHasVpn: true,
    );
    expect(d.shouldOptimize, isTrue);
  });

  test('WiFi → 移动网络 → 优化', () {
    final d = decideTianjiNetChange(
      [mobile, vpn],
      previousSig: 'wifi',
      previousHasVpn: true,
    );
    expect(d.shouldOptimize, isTrue);
    expect(d.sig, 'mobile');
  });

  test('断网不优化，恢复后优化', () {
    final off = decideTianjiNetChange(
      [none],
      previousSig: 'wifi',
      previousHasVpn: true,
    );
    expect(off.shouldOptimize, isFalse);
    final back = decideTianjiNetChange(
      [wifi, vpn],
      previousSig: off.sig,
      previousHasVpn: off.hasVpn,
    );
    expect(back.shouldOptimize, isTrue);
  });

  test('第一次事件（没有历史）也优化', () {
    final d = decideTianjiNetChange(
      [wifi],
      previousSig: null,
      previousHasVpn: false,
    );
    expect(d.shouldOptimize, isTrue);
  });
}
