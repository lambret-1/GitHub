#!/usr/bin/env python3
"""批量清除 SwiftUI 视图文件中 AI 生成的行尾中文注释（// 这是...）。
保留：// MARK:、// TODO:、// FIXME:、正常业务注释。
只处理 GitHub/Views/ 下的 .swift 文件，跳过 Syntax/Tokenizer 目录。
"""
import os
import re
import sys

ROOT = "/home/user/Doubao/chats/38446310024734978/GitHub_inspect/GitHub/Views"
SKIP_DIRS = {"Syntax", "Tokenizer", "Tokenizers"}

# 匹配行尾的 "  // 这是..." 注释（前面是代码，后面是双空格+// 这是...）
# 只删以 "这是" 开头的注释，保留其他注释
PATTERN = re.compile(r'(\s+)//\s*这是.*$')

def process_file(path: str) -> int:
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    changed = 0
    new_lines = []
    for line in lines:
        # 跳过纯注释行（整行都是 // 这是...）
        stripped = line.lstrip()
        if stripped.startswith("// 这是"):
            changed += 1
            continue
        # 处理行尾注释：代码后面跟 "  // 这是..."
        m = PATTERN.search(line)
        if m:
            # 去掉行尾注释，保留代码部分
            code_part = line[:m.start()].rstrip()
            new_lines.append(code_part + "\n")
            changed += 1
        else:
            new_lines.append(line)
    if changed > 0:
        with open(path, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
    return changed

def main():
    total = 0
    files_changed = 0
    for dirpath, dirnames, filenames in os.walk(ROOT):
        # 跳过语法高亮目录
        if any(skip in dirpath for skip in SKIP_DIRS):
            continue
        for fn in filenames:
            if not fn.endswith(".swift"):
                continue
            p = os.path.join(dirpath, fn)
            n = process_file(p)
            if n > 0:
                total += n
                files_changed += 1
                print(f"  {p}: 删除 {n} 处注释")
    print(f"\n完成：修改 {files_changed} 个文件，共删除 {total} 处行尾注释")

if __name__ == "__main__":
    main()
