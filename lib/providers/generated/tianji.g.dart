// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../tianji.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 状态页的公开实测数据。按需拉取：首页每次显示时看一眼，超过 [_staleAfter] 就重拉。
///
/// 🔴 不用后台定时器。定时器在 App 空闲或退到后台时照样打请求（每人每天上千次，
///    换不来任何用户能察觉的新鲜度），而且在 widget 测试里会以
///    「A Timer is still pending even after the widget tree was disposed」
///    把整棵树的测试弄红 —— 2026-09-30 就是这么发现的。
/// 🔴 拉不到就保持上一份；从来没拉到过就是 null。首页对 null 显示「暂时无法获取」，
///    不画红点 —— 把自己的取数失败报成线路故障会引发退款潮（红线 4 / 6）。

@ProviderFor(TianjiAiStatusState)
final tianjiAiStatusStateProvider = TianjiAiStatusStateProvider._();

/// 状态页的公开实测数据。按需拉取：首页每次显示时看一眼，超过 [_staleAfter] 就重拉。
///
/// 🔴 不用后台定时器。定时器在 App 空闲或退到后台时照样打请求（每人每天上千次，
///    换不来任何用户能察觉的新鲜度），而且在 widget 测试里会以
///    「A Timer is still pending even after the widget tree was disposed」
///    把整棵树的测试弄红 —— 2026-09-30 就是这么发现的。
/// 🔴 拉不到就保持上一份；从来没拉到过就是 null。首页对 null 显示「暂时无法获取」，
///    不画红点 —— 把自己的取数失败报成线路故障会引发退款潮（红线 4 / 6）。
final class TianjiAiStatusStateProvider
    extends $NotifierProvider<TianjiAiStatusState, TianjiAiStatus?> {
  /// 状态页的公开实测数据。按需拉取：首页每次显示时看一眼，超过 [_staleAfter] 就重拉。
  ///
  /// 🔴 不用后台定时器。定时器在 App 空闲或退到后台时照样打请求（每人每天上千次，
  ///    换不来任何用户能察觉的新鲜度），而且在 widget 测试里会以
  ///    「A Timer is still pending even after the widget tree was disposed」
  ///    把整棵树的测试弄红 —— 2026-09-30 就是这么发现的。
  /// 🔴 拉不到就保持上一份；从来没拉到过就是 null。首页对 null 显示「暂时无法获取」，
  ///    不画红点 —— 把自己的取数失败报成线路故障会引发退款潮（红线 4 / 6）。
  TianjiAiStatusStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tianjiAiStatusStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tianjiAiStatusStateHash();

  @$internal
  @override
  TianjiAiStatusState create() => TianjiAiStatusState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TianjiAiStatus? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TianjiAiStatus?>(value),
    );
  }
}

String _$tianjiAiStatusStateHash() =>
    r'92aff52cdf680675df21a8edfe8d329b62d82c7f';

/// 状态页的公开实测数据。按需拉取：首页每次显示时看一眼，超过 [_staleAfter] 就重拉。
///
/// 🔴 不用后台定时器。定时器在 App 空闲或退到后台时照样打请求（每人每天上千次，
///    换不来任何用户能察觉的新鲜度），而且在 widget 测试里会以
///    「A Timer is still pending even after the widget tree was disposed」
///    把整棵树的测试弄红 —— 2026-09-30 就是这么发现的。
/// 🔴 拉不到就保持上一份；从来没拉到过就是 null。首页对 null 显示「暂时无法获取」，
///    不画红点 —— 把自己的取数失败报成线路故障会引发退款潮（红线 4 / 6）。

abstract class _$TianjiAiStatusState extends $Notifier<TianjiAiStatus?> {
  TianjiAiStatus? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TianjiAiStatus?, TianjiAiStatus?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TianjiAiStatus?, TianjiAiStatus?>,
              TianjiAiStatus?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 订阅模板里的主分组：第一个不是 GLOBAL、成员多于 1 的 select 组（天机模板里叫「天机 TIANJI」）。

@ProviderFor(tianjiMainGroup)
final tianjiMainGroupProvider = TianjiMainGroupProvider._();

/// 订阅模板里的主分组：第一个不是 GLOBAL、成员多于 1 的 select 组（天机模板里叫「天机 TIANJI」）。

final class TianjiMainGroupProvider
    extends $FunctionalProvider<Group?, Group?, Group?>
    with $Provider<Group?> {
  /// 订阅模板里的主分组：第一个不是 GLOBAL、成员多于 1 的 select 组（天机模板里叫「天机 TIANJI」）。
  TianjiMainGroupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tianjiMainGroupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tianjiMainGroupHash();

  @$internal
  @override
  $ProviderElement<Group?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Group? create(Ref ref) {
    return tianjiMainGroup(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Group? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Group?>(value),
    );
  }
}

String _$tianjiMainGroupHash() => r'1ff27a69c210be445808c7d15a6deae4f711c6ea';

/// 拉一次公开配置，结果缓存在 provider 里。失败返回 null。

@ProviderFor(tianjiPublicConfig)
final tianjiPublicConfigProvider = TianjiPublicConfigProvider._();

/// 拉一次公开配置，结果缓存在 provider 里。失败返回 null。

final class TianjiPublicConfigProvider
    extends
        $FunctionalProvider<
          AsyncValue<TianjiPublicConfig?>,
          TianjiPublicConfig?,
          FutureOr<TianjiPublicConfig?>
        >
    with
        $FutureModifier<TianjiPublicConfig?>,
        $FutureProvider<TianjiPublicConfig?> {
  /// 拉一次公开配置，结果缓存在 provider 里。失败返回 null。
  TianjiPublicConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tianjiPublicConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tianjiPublicConfigHash();

  @$internal
  @override
  $FutureProviderElement<TianjiPublicConfig?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<TianjiPublicConfig?> create(Ref ref) {
    return tianjiPublicConfig(ref);
  }
}

String _$tianjiPublicConfigHash() =>
    r'cfcb762d6f1a7d5ccb5adf23c8b5c4125d7edc3b';
