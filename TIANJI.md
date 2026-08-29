# 天机客户端 —— FlClash 的定制分支

上游: https://github.com/chen08209/FlClash （GPL-3.0）

## 为什么 fork

客户拿到订阅地址之后，还要自己找客户端、复制粘贴、在陌生菜单里翻「从 URL 添加配置」。
这一步流失最多。定制版把它压成**点一下**。

## 第一版改了什么（2026-08-29）

**刻意只改用户可见的部分，内核与业务逻辑一行不动** —— 这样 `git merge upstream` 几乎无冲突。

| 改动 | 位置 |
|---|---|
| 应用显示名 → 天机 | `android/common/src/main/res/values/strings.xml` · `linux/packaging/deb/make_config.yaml` |
| 图标 → 天机品牌图 | Android mipmap（10 个）· macOS appiconset（7 个）· `assets/images/icon.png` |
| 新增 `tianji://` scheme | `android/app/src/main/AndroidManifest.xml` · `lib/common/window.dart` |

### ⚠️ 刻意**没有**改的

- **Java 包名 `com.follow.clash`** —— 改它要动几十个 Kotlin 文件，且每次合并上游必冲突。
  它不面向用户，改了只增加维护成本。
- **`clash://` scheme** —— **保留**。存量用户手上的旧链接还在用它，去掉等于让那些链接**静默失效**。
  两个 scheme 并存，代价只是多一行注册。
- **内核（`core/`）与所有业务逻辑** —— 一行不动。这是「同步上游几乎无痛」的全部前提。

## 内置订阅导入怎么工作

不需要在 App 里做登录 —— 上游已经支持深链，我们只是多注册一个自己的 scheme：

```
tianji://install-config?url=https://www.divinations.top/s/<token>
```

网站上的「一键导入」按钮拼出这个链接，点一下 App 就装好订阅。

⚠️ **GPL-3.0 要求分发时开源修改**，所以**任何密钥都不能进 App**。
这个方案天然满足：订阅地址本身就是客户的凭据，由网页传入，App 里不存任何秘密。

## 同步上游

```bash
git fetch upstream && git merge upstream/main
```

改动集中在 5 个文件 + 图标资源，冲突面很小。**如果哪天冲突变大，说明有人越界改了内核 —— 那是要回头看的信号。**
