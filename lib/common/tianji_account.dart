/// 账号与套餐信息 —— 来自 Xboard 的 `/api/v1/user/getSubscribe`。
///
/// 🔴 套餐名、流量额度、到期时间**一律从这里取真值**，页面上不许写死。
///    后台随时能改，写死的文案会静默漂移：页面继续正常显示，只是说的话不再是真的。
///
/// 🔴 这个接口的响应里含 `token` 与 `subscribe_url`（订阅凭证）——
///    **解析时只取需要的字段，整包绝不进日志**。订阅链接不进日志是红线 3。
library;

/// 一个账号此刻的真实状态。任何一项取不到就是 null，页面据此显示「暂时无法获取」，
/// 🔴 不回落到好看的默认值。
class TianjiAccount {
  final String email;

  /// 套餐名（后台可改）。没订阅时为 null
  final String? planName;

  /// 到期时间（秒）。**null 表示不过期**，不是「未知」——
  /// 免费档就是永久有效，把它显示成「未知」会让人以为出了问题
  final int? expiredAt;

  /// 已用字节（上行 + 下行）
  final int used;

  /// 额度字节。0 表示没有额度信息
  final int total;

  /// 距离流量重置还有几天。null = 不重置（一次性流量包）
  final int? resetDay;

  /// 同时在线设备数上限。null = 没限制
  final int? deviceLimit;

  const TianjiAccount({
    required this.email,
    this.planName,
    this.expiredAt,
    this.used = 0,
    this.total = 0,
    this.resetDay,
    this.deviceLimit,
  });

  bool get hasQuota => total > 0;

  /// 0..1。没有额度信息时返回 null —— 🔴 不要返回 0，那会画出一根「还没用」的进度条
  double? get ratio => total > 0 ? (used / total).clamp(0.0, 1.0) : null;

  /// 🔴 「永久有效」与「已过期」是两回事，不能都算成「不可用」
  bool get expired =>
      expiredAt != null &&
      DateTime.now().millisecondsSinceEpoch ~/ 1000 >= expiredAt!;
}

int? _int(Object? v) {
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// 把 getSubscribe 的 `data` 解析成 [TianjiAccount]。
///
/// 🔴 字段缺失或类型不对时**整条返回 null**，而不是拼一个半真半假的对象 ——
///    页面拿到 null 会说「暂时无法获取」，拿到半真的对象会把错的数字显示得
///    和真的一模一样，没有任何地方会报错。
TianjiAccount? parseTianjiAccount(Object? data) {
  if (data is! Map) return null;
  final email = data['email'];
  if (email is! String || email.isEmpty) return null;
  final plan = data['plan'];
  return TianjiAccount(
    email: email,
    planName:
        plan is Map &&
            plan['name'] is String &&
            (plan['name'] as String).isNotEmpty
        ? plan['name'] as String
        : null,
    expiredAt: _int(data['expired_at']),
    used: (_int(data['u']) ?? 0) + (_int(data['d']) ?? 0),
    total: _int(data['transfer_enable']) ?? 0,
    resetDay: _int(data['reset_day']),
    deviceLimit: _int(data['device_limit']),
  );
}

/// 「12.4 GB」。字节数按 1024 进位，保留到能看清的位数。
String tianjiBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  // GB 以上留两位小数，以下留整数 —— 「1.00 KB」这种精度是噪音
  return i >= 3
      ? '${v.toStringAsFixed(2)} ${units[i]}'
      : '${v.round()} ${units[i]}';
}
