#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 FoxFeature.dylib 注入到已脱壳的狐狸Meta IPA。

用法：
  python inject_ipa.py --ipa 狐狸Meta-1.3.2.ipa --dylib FoxFeature.dylib --out 狐狸Meta-狐狸助手.ipa

依赖：
  pip install lief
"""

import argparse
import os
import plistlib
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

try:
    import lief
except ImportError:
    print("缺少 lief，请先执行：pip install lief", file=sys.stderr)
    sys.exit(1)


def find_app(payload: Path) -> Path:
    apps = sorted(payload.glob("*.app"))
    if not apps:
        raise RuntimeError("Payload 里没有找到 .app")
    return apps[0]


def executable_name(app: Path) -> str:
    info = app / "Info.plist"
    with info.open("rb") as f:
        data = plistlib.load(f)
    name = data.get("CFBundleExecutable")
    if not name:
        raise RuntimeError("Info.plist 缺少 CFBundleExecutable")
    return name


def add_load_dylib(executable: Path, load_path: str) -> int:
    parsed = lief.MachO.parse(str(executable))
    if isinstance(parsed, lief.MachO.FatBinary):
        binaries = [parsed.at(i) for i in range(len(parsed))]
    else:
        binaries = [parsed]

    changed = 0
    for binary in binaries:
        names = [lib.name for lib in binary.libraries]
        if load_path in names:
            continue
        binary.add_library(load_path)
        changed += 1

    if changed == 0:
        print(f"[=] 已存在 {load_path}，跳过")
        return 0

    if isinstance(parsed, lief.MachO.FatBinary):
        parsed.write(str(executable))
    else:
        binaries[0].write(str(executable))
    print(f"[+] 已写入 {changed} 个架构: {load_path}")
    return changed


def verify(executable: Path, load_path: str) -> bool:
    parsed = lief.MachO.parse(str(executable))
    if isinstance(parsed, lief.MachO.FatBinary):
        binaries = [parsed.at(i) for i in range(len(parsed))]
    else:
        binaries = [parsed]
    for binary in binaries:
        if load_path not in [lib.name for lib in binary.libraries]:
            return False
    return True


def zip_dir(src: Path, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(src.rglob("*")):
            if p.is_dir():
                continue
            rel = p.relative_to(src).as_posix()
            info = zipfile.ZipInfo.from_file(p, rel)
            # iOS 需要可执行位；其余保持普通文件。
            mode = 0o644
            if p.suffix in ("", ".dylib", ".so") or (".framework" in rel and p.suffix == ""):
                mode = 0o755
            info.external_attr = (mode & 0xFFFF) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with p.open("rb") as f:
                z.writestr(info, f.read())


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ipa", required=True, help="原始 IPA")
    ap.add_argument("--dylib", required=True, help="编译好的 FoxFeature.dylib")
    ap.add_argument("--out", required=True, help="输出 IPA")
    ap.add_argument("--name", default="FoxFeature.dylib", help="复制到 Frameworks 后的文件名")
    args = ap.parse_args()

    ipa = Path(args.ipa).resolve()
    dylib = Path(args.dylib).resolve()
    out = Path(args.out).resolve()
    if not ipa.is_file():
        raise FileNotFoundError(ipa)
    if not dylib.is_file():
        raise FileNotFoundError(dylib)
    if ipa == out:
        raise RuntimeError("输出 IPA 不能覆盖输入 IPA")

    with tempfile.TemporaryDirectory(prefix="foxinject_") as td:
        tmp = Path(td)
        print("[*] 解包 IPA")
        with zipfile.ZipFile(ipa) as z:
            z.extractall(tmp)

        app = find_app(tmp / "Payload")
        exe = app / executable_name(app)
        if not exe.is_file():
            raise RuntimeError(f"找不到可执行文件: {exe}")

        frameworks = app / "Frameworks"
        frameworks.mkdir(exist_ok=True)
        target_dylib = frameworks / args.name
        shutil.copy2(dylib, target_dylib)
        print(f"[+] 复制 dylib -> {target_dylib.relative_to(tmp)}")

        load_path = f"@executable_path/Frameworks/{args.name}"
        add_load_dylib(exe, load_path)
        if not verify(exe, load_path):
            raise RuntimeError("注入后校验失败，未找到 LC_LOAD_DYLIB")

        print("[*] 重新打包")
        zip_dir(tmp, out)
        print(f"[+] 输出: {out}")
        print(f"[+] 大小: {out.stat().st_size / 1024 / 1024:.1f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
