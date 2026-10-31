# 手工 AOT 构建与部署（没有 Visual Studio 时）

本机没有 VS / cmake，`flutter build windows` 跑不起来，只能手工把 Dart 编成 `app.so`，替换发行包里的旧快照。

## 用哪个 Flutter

**必须与发行包里的 `flutter_windows.dll` 一致：3.35.1（Dart 3.9.0）。**

工具链放在 `D:\yys\yys\toolchains\flutter`。用别的版本（比如 3.47）编出来的 `app.so` 引擎不认，启动直接报：

```
'FlutterEngineCreateAOTData' returned 'kInvalidArguments'. Could not find isolate snapshot data.
Failed to load AOT data from: ...\data\app.so
Unable to start engine without AOT data.
```

## 两步构建

```bat
set FL=D:\yys\yys\toolchains\flutter
cd /d D:\yys\yys\oasx_shengya
python tools\sync_plugin_registrant.py
%FL%\bin\flutter.bat build bundle --release

%FL%\bin\cache\dart-sdk\bin\dartaotruntime.exe ^
  %FL%\bin\cache\artifacts\engine\windows-x64\frontend_server_aot.dart.snapshot ^
  --sdk-root %FL%\bin\cache\artifacts\engine\common\flutter_patched_sdk_product ^
  --target=flutter --aot --tfa ^
  -Ddart.vm.product=true -Ddart.vm.profile=false ^
  --packages .dart_tool\package_config.json ^
  --output-dill build\app.dill ^
  --source lib\dart_plugin_registrant.dart lib\main.dart

%FL%\bin\cache\artifacts\engine\windows-x64-release\gen_snapshot.exe ^
  --deterministic --snapshot_kind=app-aot-elf ^
  --elf=build\windows\app.so --strip build\app.dill
```

产物 `build\windows\app.so`，正常体积 11 MB 左右。

## 为什么要有一段插件注册

手工编出来的 `app.so` 不会自动跑插件注册，`GetStorage.init()` 里的 `path_provider` 抛 `MissingPluginException`，界面停在白屏。

所以：

- `tools/sync_plugin_registrant.py` 把 `.dart_tool\flutter_build\dart_plugin_registrant.dart` 复制成 `lib\dart_plugin_registrant.dart`，并在末尾补一个公开入口：
  ```dart
  void registerPluginImplementations() => _PluginRegistrant.register();
  ```
  （脚本幂等，重复跑不会重复定义。）
- `lib/main.dart` 在 `initService()` **之前**显式调用它：
  ```dart
  WidgetsFlutterBinding.ensureInitialized();
  plugin_registrant.registerPluginImplementations();
  await initService();
  ```
- `analysis_options.yaml` 把这个生成文件排除掉，否则里面 `FilePickerWindows.registerWith` 在当前 file_picker 版本上会报错。

插件有增删时，先 `flutter pub get` 让 `.dart_tool` 里的注册文件重新生成，再跑一次 sync 脚本。

## 部署

拷两样东西到发行包 `data\` 下：

```
data\app.so                          ← build\windows\app.so
data\flutter_assets\                 ← build\flutter_assets\
```

`flutter_assets` 也必须是同一版本 Flutter 的产物，跨版本混用同样白屏。发行包原版的 `app.so` 与 `flutter_assets` 记得先备份。

## 自检

```python
d = open('build/windows/app.so','rb').read()
print(d.count(b'registerPluginImplementations'))   # ≥1
print(d.count(b'income_compare'))                  # 功能字符串在
```

启动后看日志里有没有 `MissingPluginException`；窗口能不能出来、标题栏有没有内容。

## 推送到 GitHub

这台机器直连 `github.com` 会被重置，全局配置里有一条 `url.*.insteadOf` 把 `github.com` 重写到 `https://gh-proxy.com/github.com/`——那是个**只读**镜像，`git push` 会报 `remote: No anonymous write access.`

写入要显式改成 `ghproxy.net`：

```bat
git push https://<用户名>:<token>@ghproxy.net/https://github.com/shengya-0528/oasx_shengya.git main
```

- token 在 Windows 凭据管理器里，Target 是 `git:https://github.com`，账号 `shengya-0528`。git 凭据管理器（GCM）只对它认识的 host 生效，`ghproxy.net` 不在其中，所以**必须显式把 token 写进 URL**，否则推到的是空凭据，会报 `remote: Invalid username or token. Password authentication is not supported for Git operations.`
- 密码不能用于 git 操作（GitHub 2021 年就关了），必须是 token。
- 报 `No anonymous write access` = 走成了只读镜像（`gh-proxy.com`）；报 `Invalid username or token` = 凭据没带上或 token 失效。

`origin` 保持标准地址即可，读取走全局 `insteadOf` 的镜像就够了。
