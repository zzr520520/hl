# hl

dylib 构建骨架仓库：push 到 `main` 自动交叉编译 `hl.dylib`，产物在 Actions 的 Artifacts 里。

## 工作流

`.github/workflows/build.yml`

- 运行环境：`macos-15`
- SDK：自动浅克隆 [theos/sdks](https://github.com/theos/sdks)，取最新 `iPhoneOS*.sdk`
- 编译：`clang -target arm64-apple-ios14.0 -dynamiclib`，把仓库根目录所有 `*.m` / `*.c` 一起编进去
- 产物：`hl.dylib`、`hl.zip`（dylib + README），另附 `shasum -a 256`
- 失败时：完整 `build.log` 会推到 `ci-logs` 分支，方便直接看编译报错
- 手动触发：Actions 页面 `Run workflow`（`workflow_dispatch`）

## 怎么加源码

1. 把 `.m` / `.c` 放仓库根目录（`-I.` 已开，头文件同目录可直接 `#include`）
2. 需要额外链接框架，改 `build.yml` 的 `-framework` 列表
3. 产物名要改，改 `env.TARGET` / `env.OUTPUT`
4. 想拆多个目录，把 `SRCS=$(ls *.m *.c ...)` 换成 `find` 即可

## 本地交叉编译

`build.sh` 未提交，需要时按工作流里的 clang 命令照抄即可；本机没有 iOS SDK 也能靠 CI 出包。

## 当前状态

仓库里只有一个骨架 `hl.m`（构造器里打一行 `[hl] dylib loaded`），用来验证流水线通不通。
