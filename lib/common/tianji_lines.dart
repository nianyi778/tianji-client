/// 线路页的行模型 —— 纯函数，test/tianji_lines_test.dart 钉着。
///
/// 面向客户的说法只有「线路」：主分组的每个成员是一条线路（它自己可能还是个分组，
/// 比如「香港落地」下面挂着几个节点），页面只显示这一层，不把几十个节点摊开。
library;

/// 订阅模板里给买不起这一档的人放的占位项（`🔒 更多线路需升级套餐 · tianjiyun.org`）。
/// 🔴 判据是这个符号，不是写死的整句 —— 那句话在 Xboard 后台随时可改。
const tianjiLockMarker = '🔒';

bool tianjiIsLocked(String name) => name.contains(tianjiLockMarker);

class TianjiLineRow {
  /// 面向客户的线路名（主分组里的那一项）
  final String name;

  /// 背后真正在用的那条线路；等于 name 时说明它本身就是终点
  final String realName;

  /// 这一档没买，点了也用不了
  final bool locked;

  /// 当前选中的就是它
  final bool selected;

  const TianjiLineRow({
    required this.name,
    required this.realName,
    required this.locked,
    required this.selected,
  });

  /// 需要另起一行说明背后是哪条线路
  bool get showsReal => !locked && realName.isNotEmpty && realName != name;
}

/// [members] 主分组的成员名；[selectedName] 当前选中项；
/// [resolveReal] 把一项解析成它背后真正在用的线路名（组会递归解析到叶子）。
List<TianjiLineRow> buildTianjiLineRows({
  required List<String> members,
  required String? selectedName,
  required String Function(String name) resolveReal,
}) {
  return members.map((name) {
    final real = resolveReal(name);
    // 🔴 锁住与否看「背后那条」：分组本身叫「美国落地」不带锁符号，
    //    但它里面只剩占位项时，解析出来的就是那条锁。
    final locked = tianjiIsLocked(name) || tianjiIsLocked(real);
    return TianjiLineRow(
      name: name,
      realName: real,
      locked: locked,
      selected: selectedName != null && selectedName == name,
    );
  }).toList();
}
