import 'package:fl_clash/common/tianji_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TianjiProbeTarget target(String service) =>
      tianjiAiTargets.firstWhere((t) => t.service == service);

  group('判定规则与 checker 对齐', () {
    test('🔴 请求没成功是 unknown，不是 unavailable', () {
      expect(
        classifyTianjiProbe(
          target: target('Claude'),
          statusCode: null,
          body: '',
        ),
        TianjiProbeState.unknown,
      );
    });

    test('403 判不可用', () {
      expect(
        classifyTianjiProbe(
          target: target('Claude'),
          statusCode: 403,
          body: '',
        ),
        TianjiProbeState.unavailable,
      );
    });

    test('ChatGPT 的 loc=CN 判不可用，哪怕状态码是 200', () {
      expect(
        classifyTianjiProbe(
          target: target('ChatGPT'),
          statusCode: 200,
          body: 'fl=abc\nloc=CN\n',
        ),
        TianjiProbeState.unavailable,
      );
      expect(
        classifyTianjiProbe(
          target: target('ChatGPT'),
          statusCode: 200,
          body: 'fl=abc\nloc=HK\n',
        ),
        TianjiProbeState.available,
      );
    });

    test('Gemini 的 451 也判不可用', () {
      expect(
        classifyTianjiProbe(
          target: target('Gemini'),
          statusCode: 451,
          body: '',
        ),
        TianjiProbeState.unavailable,
      );
    });

    test('3xx / 5xx 说不清，报 unknown', () {
      for (final code in [302, 500, 503]) {
        expect(
          classifyTianjiProbe(
            target: target('Claude'),
            statusCode: code,
            body: '',
          ),
          TianjiProbeState.unknown,
          reason: '$code',
        );
      }
    });

    test('🔴 探测目标打的是 cdn-cgi/trace，不是首页', () {
      expect(target('ChatGPT').url, contains('/cdn-cgi/trace'));
      expect(target('Claude').url, contains('/cdn-cgi/trace'));
      expect(target('Perplexity').url, contains('/cdn-cgi/trace'));
    });
  });

  group('出口地址', () {
    test('认得出 IPv6', () {
      expect(tianjiIsIpv6('2404:6800:4004::200e'), isTrue);
      expect(tianjiIsIpv6('149.104.3.100'), isFalse);
    });
  });

  group('结论', () {
    const allOk = {
      'ChatGPT': TianjiProbeState.available,
      'Claude': TianjiProbeState.available,
    };

    test('没连上就说没连上，不报故障', () {
      final v = tianjiVerdict(running: false, exitIp: null, ai: const {});
      expect(v.level, TianjiCheckLevel.unknown);
      expect(v.code, 'notRunning');
    });

    test('🔴 测不出出口时是 unknown，不是红色', () {
      final v = tianjiVerdict(running: true, exitIp: null, ai: const {});
      expect(v.level, TianjiCheckLevel.unknown);
      expect(v.code, 'noExit');
    });

    test('有服务不可用 → 红色并点名', () {
      final v = tianjiVerdict(
        running: true,
        exitIp: '149.104.3.100',
        ai: const {
          'ChatGPT': TianjiProbeState.available,
          'Claude': TianjiProbeState.unavailable,
        },
        suggestedLine: '香港落地',
      );
      expect(v.level, TianjiCheckLevel.bad);
      expect(v.code, 'aiDown');
      expect(v.services, ['Claude']);
      expect(v.suggestedLine, '香港落地');
    });

    test('🔴 不可用又走了 IPv6 时，结论要带上成因', () {
      final v = tianjiVerdict(
        running: true,
        exitIp: '2404:6800:4004::200e',
        ai: const {'Claude': TianjiProbeState.unavailable},
      );
      expect(v.code, 'aiDownIpv6');
    });

    test('都能用但走了 IPv6 → 黄色提醒', () {
      final v = tianjiVerdict(running: true, exitIp: '2404:6800::1', ai: allOk);
      expect(v.level, TianjiCheckLevel.warn);
      expect(v.code, 'ipv6');
    });

    test('有服务测不出 → 黄色，不冒充正常', () {
      final v = tianjiVerdict(
        running: true,
        exitIp: '149.104.3.100',
        ai: const {
          'ChatGPT': TianjiProbeState.available,
          'Claude': TianjiProbeState.unknown,
        },
      );
      expect(v.level, TianjiCheckLevel.warn);
      expect(v.code, 'partialUnknown');
    });

    test('全绿才说正常', () {
      final v = tianjiVerdict(
        running: true,
        exitIp: '149.104.3.100',
        ai: allOk,
      );
      expect(v.level, TianjiCheckLevel.ok);
      expect(v.code, 'allGood');
    });
  });
}
