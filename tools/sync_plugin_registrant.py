#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""把 Flutter 生成的 dart_plugin_registrant 同步进 lib/，并补上公开注册入口。

为什么需要这一步
----------------
手工 AOT 构建（frontend_server --aot + gen_snapshot 直出 app.so）不走
`flutter build windows`。引擎在 root isolate 上按库 URI
`dart_plugin_registrant.dart` 精确查找注册表，手工构建出来的库 URI 是绝对
file 路径，匹配失败 → 生成文件里的 `_PluginRegistrant.register()` 永远不会
被调用 → path_provider 等纯 Dart 插件抛 MissingPluginException、启动卡白屏。

做法：把生成文件复制到 `lib/dart_plugin_registrant.dart`（库 URI 变成相对
lib 的 `dart_plugin_registrant.dart`），并在末尾补一个公开函数，由
`lib/main.dart` 在 `WidgetsFlutterBinding.ensureInitialized()` 之后显式调用。
注册因此不再依赖引擎的库查找。

什么时候要重跑
--------------
`flutter pub get` 之后、`pubspec.yaml` 增删插件之后、`.dart_tool` 被清掉
之后——也就是 `.dart_tool/flutter_build/dart_plugin_registrant.dart`
重新生成之后。重跑本脚本再重新 AOT 编译即可。

用法：
    python tools/sync_plugin_registrant.py
"""

from __future__ import annotations

import sys
from pathlib import Path

SRC = Path(".dart_tool/flutter_build/dart_plugin_registrant.dart")
DST = Path("lib/dart_plugin_registrant.dart")

# 我们补过的尾巴统一以这行注释开头：先截掉旧尾巴再重新追加，避免
# `_registerPlugins` 被定义两遍（重复定义会直接编译失败）。
TAIL_HEAD = "// 手工 AOT 构建补丁"

APPENDIX = """// 手工 AOT 构建补丁：flutter 引擎在 root isolate 上按库 URI 找
// `dart_plugin_registrant.dart`，手工 AOT 构建匹配不到，注册不会自动跑。
// 这里补两个入口：公开的给 main.dart 显式调用，`_registerPlugins` 留给
// 引擎万一按顶层函数名 Dart_Invoke 时兜底。
/// 手工 AOT 构建补丁（公开入口）：main.dart 在 `WidgetsFlutterBinding`
/// 初始化之后直接调用它。
void registerPluginImplementations() => _PluginRegistrant.register();

@pragma('vm:entry-point', 'call')
void _registerPlugins() => _PluginRegistrant.register();
"""


def main() -> int:
    if not SRC.is_file():
        print(f"[x] 找不到生成文件：{SRC}")
        print("    先跑一次 flutter pub get / flutter build 让它生成。")
        return 1

    text = SRC.read_text(encoding="utf-8")
    cut = text.find(TAIL_HEAD)
    if cut != -1:
        text = text[:cut].rstrip("\n") + "\n"
    body = text.rstrip("\n") + "\n" + APPENDIX

    DST.parent.mkdir(parents=True, exist_ok=True)
    old = DST.read_text(encoding="utf-8") if DST.is_file() else None
    if old == body:
        print(f"[=] {DST} 已是最新（含公开入口）")
        return 0

    DST.write_text(body, encoding="utf-8")
    print(f"[+] {DST} 已写入 {len(body)} 字符（含公开入口）")
    print("    接着重新做手工 AOT 编译，so 里才会有 registerPluginImplementations。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
