// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../tianji.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 状态页的公开实测数据，每分钟拉一次。拉不到就保持上一份，从来没拉到过就是 null。
/// 🔴 拉不到 ≠ 全部不可用：首页对 null 显示「暂时无法获取」，不画红点（红线 4 / 6）。

@ProviderFor(TianjiAiStatusState)
final tianjiAiStatusStateProvider = TianjiAiStatusStateProvider._();

/// 状态页的公开实测数据，每分钟拉一次。拉不到就保持上一份，从来没拉到过就是 null。
/// 🔴 拉不到 ≠ 全部不可用：首页对 null 显示「暂时无法获取」，不画红点（红线 4 / 6）。
final class TianjiAiStatusStateProvider
    extends $NotifierProvider<TianjiAiStatusState, TianjiAiStatus?> {
  /// 状态页的公开实测数据，每分钟拉一次。拉不到就保持上一份，从来没拉到过就是 null。
  /// 🔴 拉不到 ≠ 全部不可用：首页对 null 显示「暂时无法获取」，不画红点（红线 4 / 6）。
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
    r'36de113baabdc8937337b500237af40c14870f3b';

/// 状态页的公开实测数据，每分钟拉一次。拉不到就保持上一份，从来没拉到过就是 null。
/// 🔴 拉不到 ≠ 全部不可用：首页对 null 显示「暂时无法获取」，不画红点（红线 4 / 6）。

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
