import 'package:fl_clash/common/tianji_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('剥掉 v 前缀、build 号和预发布后缀', () {
    expect(tianjiBaseVersion('v0.8.96-tianji.7'), '0.8.96');
    expect(tianjiBaseVersion('0.8.96+2026081701'), '0.8.96');
    expect(tianjiBaseVersion('v0.8.98'), '0.8.98');
  });

  test('🔴 我们自己的 tag 不会让更新检查抛异常（抛了就静默失效）', () {
    expect(
      tianjiHasNewerRelease(
        remoteTag: 'v0.8.96-tianji.7',
        localVersion: '0.8.96',
      ),
      isFalse,
    );
  });

  test('基础版本更高才算有更新', () {
    expect(
      tianjiHasNewerRelease(remoteTag: 'v0.8.98', localVersion: '0.8.96'),
      isTrue,
    );
    expect(
      tianjiHasNewerRelease(remoteTag: 'v0.8.95', localVersion: '0.8.96'),
      isFalse,
    );
    expect(
      tianjiHasNewerRelease(remoteTag: 'v1.0.0', localVersion: '0.9.99'),
      isTrue,
    );
  });

  test('看不懂的版本号当作没有更新，不骚扰用户', () {
    expect(
      tianjiHasNewerRelease(remoteTag: 'nightly', localVersion: '0.8.96'),
      isFalse,
    );
    expect(
      tianjiHasNewerRelease(remoteTag: '', localVersion: '0.8.96'),
      isFalse,
    );
  });

  test('位数不齐也不崩', () {
    expect(
      tianjiHasNewerRelease(remoteTag: 'v1', localVersion: '0.8.96'),
      isTrue,
    );
    expect(
      tianjiHasNewerRelease(remoteTag: 'v0.9', localVersion: '0.8.96'),
      isTrue,
    );
  });
}
