#!/usr/bin/env python3
"""
bin-bypass - splits binary files into 10MB fragments for VK upload, reassembles them back.
Usage:
    bin-bypass.py split <path_to_binary> [simple_vk_bypass]
    bin-bypass.py build <path_to_info.txt>
"""

import sys
import os

FRAGMENT_SIZE = 10485760  # 10 MB
CAESAR_SHIFT = 13


def caesar_encode(data: bytearray) -> bytearray:
    return bytearray((b + CAESAR_SHIFT) & 0xFF for b in data)


def caesar_decode(data: bytearray) -> bytearray:
    return bytearray((b - CAESAR_SHIFT) & 0xFF for b in data)


def open_file(file_path: str):
    if not os.path.isfile(file_path):
        print(f"[bin-bypass][x]: Cant reach file: {file_path}", file=sys.stderr)
        return None, None
    filename = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)
    print(f"[bin-bypass][v]: filename: {filename}")
    print(f"[bin-bypass][v]: file size: {file_size} bytes")
    return filename, file_size


def save_fragments(file_path: str, enc_type: int):
    filename, file_size = open_file(file_path)
    if filename is None:
        return

    fragments_count = (file_size + FRAGMENT_SIZE - 1) // FRAGMENT_SIZE
    print(f"[bin-bypass][v]: binary file will be splited to {fragments_count} fragments")
    print(f"[bin-bypass][v]: this tool will generate next {fragments_count + 1} files:")
    print(f"\t\t[1] info.txt")

    with open("info.txt", "w") as info:
        info.write(f"f_name = {filename}\n")
        info.write(f"f_size = {file_size}\n")
        info.write(f"enc_type = {enc_type}\n")
        info.write(f"f_count = {fragments_count}")

    with open(file_path, "rb") as src:
        for i in range(fragments_count):
            frag_name = f"f{i}.txt"
            print(f"\t\t[{i + 2}] {frag_name}")
            chunk = bytearray(src.read(FRAGMENT_SIZE))
            if enc_type == 1:
                chunk = caesar_encode(chunk)
            with open(frag_name, "wb") as fout:
                fout.write(chunk)


def load_fragments(info_file_path: str):
    if not os.path.isfile(info_file_path):
        print(f"[bin-bypass][x]: cant reach info file \"{info_file_path}\"", file=sys.stderr)
        return None

    info = {}
    with open(info_file_path, "r") as f:
        for line in f:
            key, _, value = line.strip().partition(" = ")
            info[key] = value

    filename     = info["f_name"]
    file_size    = int(info["f_size"])
    enc_type     = int(info["enc_type"])
    frag_count   = int(info["f_count"])

    all_ok = True
    for i in range(frag_count):
        frag_name = f"f{i}.txt"
        print(f"[bin-bypass]: checking file {frag_name} - ", end="")
        if os.path.isfile(frag_name):
            print("[v] file available")
        else:
            print("[x] cant reach this file")
            all_ok = False

    if not all_ok:
        return None

    return filename, enc_type, frag_count


def save_file(info_file_path: str):
    result = load_fragments(info_file_path)
    if result is None:
        return
    filename, enc_type, frag_count = result

    print(f"[bin-bypass][v]: starting reassembling of origin binary")
    with open(filename, "wb") as out:
        for i in range(frag_count):
            frag_name = f"f{i}.txt"
            print(f"[bin-bypass]: trying to process file \"{frag_name}\" - ", end="")
            if not os.path.isfile(frag_name):
                print(f"\n[bin-bypass][x]: failed to open fragment file \"{frag_name}\"", file=sys.stderr)
                return
            with open(frag_name, "rb") as fin:
                chunk = bytearray(fin.read())
            if enc_type == 1:
                chunk = caesar_decode(chunk)
            out.write(chunk)
            print("[v]")


def help_msg():
    print("To use this tool follow this syntax:")
    print("bin-bypass.py split <path_to_binary> [EXT] - to split binary")
    print("bin-bypass.py build <path_to_info.txt>     - to build up binary")
    print("EXT can be:")
    print("1. simple_vk_bypass - uses caesar shift to bypass vk.com automoderation of files")
    print("other EXT maybe coming soon...")


def main():
    args = sys.argv[1:]

    if len(args) == 0:
        help_msg()
        return

    cmd = args[0]

    if cmd == "split":
        if len(args) < 2:
            print("[bin-bypass][x]: syntax error", file=sys.stderr)
            help_msg()
            return
        file_path = args[1]
        enc_type = 0
        if len(args) == 3:
            if args[2] == "simple_vk_bypass":
                enc_type = 1
                print(f"[bin-bypass][v]: splitting origin file")
                print(f"[bin-bypass][v]: EXT - \"{args[2]}\"")
            else:
                print(f"[bin-bypass][x]: unrecoginzed EXT - \"{args[2]}\"", file=sys.stderr)
                return
        else:
            print("[bin-bypass][v]: splitting origin file")
            print("[bin-bypass][!]: without EXT")
        save_fragments(file_path, enc_type)

    elif cmd == "build":
        if len(args) < 2:
            print("[bin-bypass][x]: syntax error", file=sys.stderr)
            help_msg()
            return
        print("[bin-bypass][v]: building origin file")
        if len(args) == 3 and args[2] == "simple_vk_bypass":
            print(f"[bin-bypass][v]: EXT - will parse from info.txt")
        else:
            print("[bin-bypass][!]: without EXT")
        save_file(args[1])

    else:
        print(f"[bin-bypass][x]: unrecoginzed CMD - \"{cmd}\"", file=sys.stderr)
        help_msg()

    print("[bin-bypass][v]: tool ended work")


if __name__ == "__main__":
    main()
