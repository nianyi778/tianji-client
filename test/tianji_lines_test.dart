import 'package:fl_clash/common/tianji_lines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String real(String name) => switch (name) {
    '自动选择' => '🇭🇰 香港 · 01',
    '香港落地' => '🇭🇰 香港 · 02',
    '美国落地' => '🔒 更多线路需升级套餐 · tianjiyun.org',
    _ => name,
  };

  test('分组解析到背后真正在用的线路', () {
    final rows = buildTianjiLineRows(
      members: ['自动选择', '香港落地'],
      selectedName: '自动选择',
      resolveReal: real,
    );
    expect(rows.first.realName, '🇭🇰 香港 · 01');
    expect(rows.first.selected, isTrue);
    expect(rows.first.showsReal, isTrue);
    expect(rows[1].selected, isFalse);
  });

  test('🔴 分组名不带锁符号，但里面只剩占位项时也算锁住', () {
    final rows = buildTianjiLineRows(
      members: ['美国落地'],
      selectedName: null,
      resolveReal: real,
    );
    expect(rows.single.locked, isTrue);
    // 锁住的行不展示「背后是哪条」——那句话是占位文案，不是线路名
    expect(rows.single.showsReal, isFalse);
  });

  test('判据是锁符号本身，后台改了那句文案也仍然判得出来', () {
    expect(tianjiIsLocked('🔒 升级后可用'), isTrue);
    expect(tianjiIsLocked('🔒'), isTrue);
    expect(tianjiIsLocked('🇭🇰 香港 · 01'), isFalse);
  });

  test('线路本身就是终点时不重复显示', () {
    final rows = buildTianjiLineRows(
      members: ['🇭🇰 香港 · 01'],
      selectedName: '🇭🇰 香港 · 01',
      resolveReal: real,
    );
    expect(rows.single.showsReal, isFalse);
    expect(rows.single.locked, isFalse);
  });

  test('没有任何选中项时不会误标', () {
    final rows = buildTianjiLineRows(
      members: ['自动选择'],
      selectedName: null,
      resolveReal: real,
    );
    expect(rows.single.selected, isFalse);
  });
}
