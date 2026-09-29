import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/pages/home.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首屏门卫：没有任何配置、也没选过「手动导入」→ 登录页；否则 → 上游首页。
/// 配置列表来自数据库流，加载完之前什么都不画，免得老用户闪一下登录页。
class TianjiGate extends ConsumerWidget {
  const TianjiGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesStreamProvider);
    final skipLogin = ref.watch(
      tianjiSettingProvider.select((state) => state.skipLogin),
    );
    return profiles.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const HomePage(),
      data: (list) => list.isEmpty && !skipLogin
          ? const TianjiLoginPage()
          : const HomePage(),
    );
  }
}

class TianjiLoginPage extends ConsumerStatefulWidget {
  const TianjiLoginPage({super.key});

  @override
  ConsumerState<TianjiLoginPage> createState() => _TianjiLoginPageState();
}

class _TianjiLoginPageState extends ConsumerState<TianjiLoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: ref.read(tianjiSettingProvider).email);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await globalState.loadingRun(
        tag: null,
        silence: false,
        title: context.appLocalizations.tianjiLoginFailed,
        () => ref
            .read(tianjiActionProvider.notifier)
            .login(_email.text, _password.text),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeApiBase() async {
    final appLocalizations = context.appLocalizations;
    final current = ref.read(tianjiSettingProvider).apiBase;
    final value = await globalState.showCommonDialog<String>(
      child: InputDialog(
        title: appLocalizations.tianjiApiBase,
        value: current,
        resetValue: defaultTianjiApiBase,
        keyboardType: TextInputType.url,
        validator: (v) {
          final uri = Uri.tryParse(v ?? '');
          if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
            return appLocalizations.emptyTip(appLocalizations.tianjiApiBase);
          }
          return null;
        },
      ),
    );
    if (value == null || value.isEmpty) return;
    ref
        .read(tianjiSettingProvider.notifier)
        .update((state) => state.copyWith(apiBase: value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        appLocalizations.tianjiLoginTitle,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appLocalizations.tianjiLoginSub,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _email,
                        autofillHints: const [AutofillHints.username],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: appLocalizations.tianjiEmail,
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) => (v ?? '').contains('@')
                            ? null
                            : appLocalizations.emptyTip(
                                appLocalizations.tianjiEmail,
                              ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        autofillHints: const [AutofillHints.password],
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: appLocalizations.tianjiPassword,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v ?? '').length >= 8
                            ? null
                            : appLocalizations.emptyTip(
                                appLocalizations.tianjiPassword,
                              ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(appLocalizations.tianjiLoginAndConnect),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => globalState.openUrl(
                          '${ref.read(tianjiSettingProvider).apiBase}/#/register',
                        ),
                        child: Text(appLocalizations.tianjiRegister),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: _changeApiBase,
                            child: Text(appLocalizations.tianjiChangeApiBase),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(tianjiSettingProvider.notifier)
                                .update(
                                  (state) => state.copyWith(skipLogin: true),
                                ),
                            child: Text(appLocalizations.tianjiManualImport),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appLocalizations.tianjiLoginFoot,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
