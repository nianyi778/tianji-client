part of '../action.dart';

/// 天机账号：登录即用 + 网络变化后自动优化。
///
/// 登录走 Xboard 公开的用户接口（它自带的面板就是这么调的），用的是用户自己的账号密码，
/// 不涉及任何管理密钥。拿到订阅链接后当成一个普通配置导入，其余全部复用上游逻辑。
@Riverpod(keepAlive: true)
class TianjiAction extends _$TianjiAction {
  Timer? _netTimer;
  String? _lastNetSig;
  bool _lastHasVpn = false;
  bool _optimizing = false;

  @override
  void build() {}

  /// 专用 HTTP 客户端：
  /// - 走上游同一套 findProxy（内核在跑就经本地代理，没跑就直连），主域名被墙时开着代理也能登录；
  /// - 🔴 不接受坏证书。上游的 HttpOverrides 对所有请求都 `badCertificateCallback = true`，
  ///   给账号密码这条路必须关掉。
  Dio _dio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        responseType: ResponseType.json,
        validateStatus: (_) => true,
        headers: {'User-Agent': globalState.ua},
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (_, _, _) => false;
        client.findProxy = FlClashHttpOverrides.handleFindProxy;
        return client;
      },
    );
    return dio;
  }

  String get _apiBase => ref
      .read(tianjiSettingProvider)
      .apiBase
      .trim()
      .replaceAll(RegExp(r'/+$'), '');

  Map<String, dynamic> _unwrap(Response res) {
    final body = res.data;
    if (body is Map && body['data'] is Map && res.statusCode == 200) {
      return Map<String, dynamic>.from(body['data'] as Map);
    }
    final message = body is Map ? body['message'] : null;
    throw message is String && message.isNotEmpty
        ? message
        : currentAppLocalizations.tianjiNetworkError;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      return _unwrap(await _dio().post('$_apiBase$path', data: data));
    } on DioException catch (e) {
      commonPrint.log(
        'tianji post $path failed: ${e.type}',
        logLevel: LogLevel.warning,
      );
      throw currentAppLocalizations.tianjiNetworkError;
    }
  }

  Future<Map<String, dynamic>> _get(String path, String authData) async {
    try {
      return _unwrap(
        await _dio().get(
          '$_apiBase$path',
          options: Options(headers: {'Authorization': authData}),
        ),
      );
    } on DioException catch (e) {
      commonPrint.log(
        'tianji get $path failed: ${e.type}',
        logLevel: LogLevel.warning,
      );
      throw currentAppLocalizations.tianjiNetworkError;
    }
  }

  /// 登录 → 拉订阅 → 导入为当前配置 → 启动。任何一步失败都抛可读的字符串，交给 loadingRun 弹出。
  Future<void> login(String email, String password) async {
    final auth = await _post('/api/v1/passport/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    final authData = auth['auth_data'];
    if (authData is! String || authData.isEmpty) {
      throw currentAppLocalizations.tianjiNetworkError;
    }
    final sub = await _get('/api/v1/user/getSubscribe', authData);
    final url = sub['subscribe_url'];
    if (url is! String || url.isEmpty) {
      throw currentAppLocalizations.tianjiNoSubscription;
    }
    final profile = await Profile.normal(
      label: currentAppLocalizations.tianjiProfileLabel,
      url: url,
    ).update();

    final previousId = ref.read(tianjiSettingProvider).profileId;
    if (previousId != null && previousId != profile.id) {
      await ref.read(profilesActionProvider.notifier).deleteProfile(previousId);
    }
    ref.read(profilesProvider.notifier).put(profile);
    ref.read(currentProfileIdProvider.notifier).value = profile.id;
    ref
        .read(tianjiSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            email: email.trim(),
            authData: authData,
            profileId: profile.id,
            skipLogin: false,
          ),
        );
    await ref
        .read(setupActionProvider.notifier)
        .setRunning(true, initialize: !ref.read(initProvider));
  }

  Future<void> logout() async {
    await ref.read(setupActionProvider.notifier).setRunning(false);
    final id = ref.read(tianjiSettingProvider).profileId;
    if (id != null) {
      await ref.read(profilesActionProvider.notifier).deleteProfile(id);
    }
    ref
        .read(tianjiSettingProvider.notifier)
        .update(
          (state) => state.copyWith(
            email: '',
            authData: '',
            profileId: null,
            skipLogin: false,
          ),
        );
  }

  /// 系统报告网络变化。
  ///
  /// 自己开关 VPN 也会触发（[wifi] ↔ [wifi, vpn]），那种只有 vpn 标志变的事件要忽略，
  /// 否则每次点「连接」都会跟着测一轮。换 WiFi 时 connectivity_plus 会再发一次 [wifi]，
  /// 内容和上次一样但 vpn 没变 —— 这正是要处理的情况。
  void onConnectivityChanged(List<ConnectivityResult> results) {
    final decision = decideTianjiNetChange(
      results,
      previousSig: _lastNetSig,
      previousHasVpn: _lastHasVpn,
    );
    _lastNetSig = decision.sig;
    _lastHasVpn = decision.hasVpn;
    if (!decision.shouldOptimize) return;
    if (!ref.read(tianjiSettingProvider).autoOptimize) return;
    if (!ref.read(isStartProvider)) return;
    _netTimer?.cancel();
    // 切网头一两秒 DNS 还没好，立刻测会全红
    _netTimer = Timer(const Duration(seconds: 2), optimizeAfterNetworkChange);
  }

  /// 你在 FlClash 里手动做的：关开、测速、找最快 —— 这里自动做，并且不断开代理。
  /// 当前线路还活着就不动；只有超时了才切到最快的，并提示。
  Future<void> optimizeAfterNetworkChange() async {
    if (_optimizing || !ref.read(isStartProvider)) return;
    _optimizing = true;
    try {
      // 卡住的 TCP 连接是「换了 WiFi 就不行」的直接原因
      await coreController.closeConnections();
      await ref.read(proxiesActionProvider.notifier).updateGroups();
      final groups = ref.read(groupsProvider);
      final main = groups.firstWhereOrNull(
        (g) =>
            g.type == GroupType.Selector &&
            g.name != 'GLOBAL' &&
            g.all.length > 1,
      );
      if (main == null) return;
      final selectedMap = ref.read(currentProfileProvider)?.selectedMap ?? {};
      final delays = <String, int>{};
      for (final batch in main.all.batch(maxConcurrentDelayTests)) {
        await Future.wait(
          batch.map((proxy) async {
            final state = computeRealSelectedProxyState(
              proxy.name,
              groups: groups,
              selectedMap: selectedMap,
            );
            if (state.proxyName.isEmpty) return;
            final testUrl = state.testUrl.takeFirstValid([
              ref.read(realTestUrlProvider(main.testUrl)),
            ]);
            try {
              final delay = await coreController.getDelay(
                testUrl,
                state.proxyName,
              );
              ref.read(proxiesActionProvider.notifier).setDelay(delay);
              delays[proxy.name] = delay.value ?? -1;
            } catch (_) {
              ref
                  .read(proxiesActionProvider.notifier)
                  .setDelay(
                    Delay(url: testUrl, name: state.proxyName, value: -1),
                  );
              delays[proxy.name] = -1;
            }
          }),
        );
      }
      final current = main.getCurrentSelectedName(selectedMap[main.name] ?? '');
      final currentDelay = delays[current] ?? -1;
      if (currentDelay > 0) {
        globalState.showNotifier(currentAppLocalizations.tianjiNetChangedOk);
        return;
      }
      final alive = delays.entries.where((e) => e.value > 0).toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      if (alive.isEmpty) {
        globalState.showNotifier(
          currentAppLocalizations.tianjiNetChangedAllDown,
        );
        return;
      }
      final best = alive.first;
      await ref
          .read(proxiesActionProvider.notifier)
          .changeProxy(groupName: main.name, proxyName: best.key);
      ref
          .read(profilesActionProvider.notifier)
          .updateCurrentSelectedMap(main.name, best.key);
      ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
      globalState.showNotifier(
        currentAppLocalizations.tianjiNetChangedSwitched(best.key, best.value),
      );
    } catch (e) {
      commonPrint.log('tianji optimize failed: $e', logLevel: LogLevel.warning);
    } finally {
      _optimizing = false;
    }
  }
}
