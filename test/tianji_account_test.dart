import 'package:fl_clash/common/tianji_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseTianjiAccount', () {
    test('取到全部字段', () {
      final a = parseTianjiAccount({
        'email': 'a@b.com',
        'plan': {'name': 'AI 住宅'},
        'expired_at': 1800000000,
        'u': 100,
        'd': 200,
        'transfer_enable': 1000,
        'reset_day': 12,
        'device_limit': 3,
      })!;
      expect(a.email, 'a@b.com');
      expect(a.planName, 'AI 住宅');
      expect(a.used, 300);
      expect(a.total, 1000);
      expect(a.ratio, 0.3);
      expect(a.resetDay, 12);
      expect(a.deviceLimit, 3);
    });

    test('🔴 字段缺失时整条返回 null，不拼一个半真半假的对象', () {
      expect(parseTianjiAccount(null), isNull);
      expect(parseTianjiAccount('nope'), isNull);
      expect(
        parseTianjiAccount({
          'plan': {'name': 'x'},
        }),
        isNull,
        reason: '没有 email',
      );
      expect(parseTianjiAccount({'email': ''}), isNull);
    });

    test('🔴 没订阅时 planName 是 null，不是空字符串', () {
      final a = parseTianjiAccount({'email': 'a@b.com'})!;
      expect(a.planName, isNull);
      expect(a.total, 0);
      expect(a.hasQuota, isFalse);
    });

    test('🔴 没有额度时 ratio 是 null —— 返回 0 会画出一根「还没用」的进度条', () {
      final a = parseTianjiAccount({'email': 'a@b.com', 'u': 5})!;
      expect(a.ratio, isNull);
    });

    test('🔴 expired_at 为 null 表示永久有效，不算过期', () {
      final a = parseTianjiAccount({'email': 'a@b.com'})!;
      expect(a.expiredAt, isNull);
      expect(a.expired, isFalse);
    });

    test('已过期与未过期分得开', () {
      final past = parseTianjiAccount({
        'email': 'a@b.com',
        'expired_at': 1000,
      })!;
      final future = parseTianjiAccount({
        'email': 'a@b.com',
        'expired_at': 4000000000,
      })!;
      expect(past.expired, isTrue);
      expect(future.expired, isFalse);
    });

    test('字符串形式的数字也认', () {
      final a = parseTianjiAccount({
        'email': 'a@b.com',
        'u': '100',
        'd': '200',
        'transfer_enable': '1000',
      })!;
      expect(a.used, 300);
      expect(a.total, 1000);
    });

    test('用量超过额度时 ratio 封在 1，不画出超过 100% 的条', () {
      final a = parseTianjiAccount({
        'email': 'a@b.com',
        'u': 2000,
        'transfer_enable': 1000,
      })!;
      expect(a.ratio, 1.0);
    });
  });

  group('tianjiBytes', () {
    test('按 1024 进位', () {
      expect(tianjiBytes(0), '0 B');
      expect(tianjiBytes(1024), '1 KB');
      expect(tianjiBytes(1024 * 1024), '1 MB');
      expect(tianjiBytes(1073741824), '1.00 GB');
      expect(tianjiBytes(1099511627776), '1.00 TB');
    });

    test('GB 以下不留小数 —— 「1.00 KB」那种精度是噪音', () {
      expect(tianjiBytes(1536), '2 KB');
      expect(tianjiBytes(1610612736), '1.50 GB');
    });
  });
}
