# 狐狸助手（FoxFeature.dylib）

面向 `com.feiouxun.foxmeta`（狐狸Meta 1.3.2，可执行文件 `skychat`）的可注入功能 dylib。

## 功能

- 群成员群发：自动读取已加入群、拉取群成员，支持多选、全选、清除，批量发私聊文本。
- 定时动态：设定时间点，到点自动打开发布页并填入内容发布；支持每天重复。
- 自动回复：hook `IMListenerManager` 收消息回调，按关键词自动回复发给自己的文本消息；关键词留空表示全部。
- 群转发：选择多个群，把输入或剪贴板文本转发到这些群。
- 设置页入口：在设置页包含“商城”的 Cell 下方插入“🦊 狐狸助手”入口；找不到时回退到 `tableFooter`。
- 双指双击：任意界面用两根手指双击，打开/关闭狐狸助手面板。

## 目录

```text
Sources/
  FoxModels.h/.m       群、成员、定时动态、回复规则模型
  FoxStore.h/.m        NSUserDefaults 持久化
  FoxBridge.h/.m       腾讯 ImSDK_Plus 桥接、动态发布 UI 自动化
  FoxScheduler.h/.m    定时动态轮询与补发
  FoxAutoReply.h/.m    收消息 hook 与自动回复
  FoxUI.h/.m           群转发、自动回复、定时动态、设置入口、FoxUI
  FoxDashboard.m       助手首页、群成员群发页
  FoxAssistant.h/.m    constructor、手势、设置页 hook、启动接线
  FoxUIShared.h        公共 UIKit 小工具
Makefile
control
.github/workflows/build.yml
inject/inject_ipa.py
inject/requirements.txt
```

## GitHub Actions 构建

1. 把整个目录推到 GitHub 仓库（默认分支 `main` 或 `master`）。
2. 打开 Actions → `Build FoxFeature dylib` → `Run workflow`。
3. 构建完成后下载 artifact `FoxFeature-dylib`，里面有：
   - `FoxFeature.dylib`
   - `inject/`
   - `README.md`

工作流使用 `macos-14` + Theos + `theos/sdks`，产物已用 `ldid -S` 做 ad-hoc 签名。

## 本地构建（可选，需要 macOS + Theos）

```bash
export THEOS=$HOME/theos
make clean
make -j$(sysctl -n hw.ncpu) FINALPACKAGE=1
find .theos -name FoxFeature.dylib
```

## 注入 IPA

原始 IPA 必须是已脱壳版本（本项目的 `狐狸Meta-1.3.2.ipa` 的 44 个 Mach-O 均为 `crypt_id=0`）。

```bash
python3 -m pip install -r inject/requirements.txt
python3 inject/inject_ipa.py \
  --ipa 狐狸Meta-1.3.2.ipa \
  --dylib FoxFeature.dylib \
  --out 狐狸Meta-狐狸助手.ipa
```

脚本会：

1. 解包 IPA；
2. 把 dylib 复制到 `Payload/<App>.app/Frameworks/FoxFeature.dylib`；
3. 用 LIEF 给主可执行文件添加 `LC_LOAD_DYLIB`，路径为 `@executable_path/Frameworks/FoxFeature.dylib`；
4. 重新打包，保留可执行位。

## 安装

注入后的 IPA 未签名，需要用 Sideloadly / AltStore / TrollStore 等工具安装并签名。自签后如果 App 启动闪退，优先检查：

- IPA 是否被重新签名；
- `Frameworks/FoxFeature.dylib` 是否存在；
- 主可执行文件是否真的有 `LC_LOAD_DYLIB`（脚本会校验）；
- 设备是否 arm64/arm64e，dylib 是否为对应架构。

## 使用

1. 打开狐狸Meta，进入设置页，找到“🦊 狐狸助手”入口。
2. 或在任意界面双指双击，打开助手面板。
3. 首次使用先在“群成员群发”里选群；如果自动群列表为空，可手动输入群 ID。
4. 定时动态到点会自己打开发布页，App 需要在前台；后台被挂起时回到前台会补发。
5. 自动回复规则在“自动回复”页添加；关键词为空表示回复所有文本消息，同一用户 5 秒内只回一次。

## 已知限制

- 群列表/群成员/发消息走腾讯 `ImSDK_Plus`。如果当前账号实际走悟空 `WuKongIMSDK`，需要在 `FoxBridge.m` 里补悟空分支。
- 动态发布是 UI 自动化：查找 `SkyMomentPublishViewController`、填充 `UITextView`、点“发布/发送”。如果 1.3.2 的实际发布页类名或按钮标题不同，需要按真机层级调整 `FoxBridge.m` 的 `publishMoment:`。
- 设置入口按可见 Cell 的 label 是否包含“商城”定位；如果设置页不是 UITableView，或“商城”不在可见 Cell，会退化为 `tableFooterView`。
- 自动回复 hook 目标是 `IMListenerManager` 的 `handleOnRecvNewMessage:` 或 `onRecvNewMessage:`；如果类名/方法名变化，改 `FoxAutoReply.m` 的 `installHook`。
- 定时动态依赖前台计时器（20 秒轮询），不是后台守护；锁屏/后台不会准点发布。
- 群发是逐条串行发送，成员很多时耗时较长；中途退出页面不会取消已在进行的发送。

## 调试

Console.app 过滤 `FoxAssistant` 可看到：

- 自动回复 hook 是否挂载；
- 双指双击手势是否安装；
- 定时动态发布成功/失败；
- 群成员/消息发送失败原因。
