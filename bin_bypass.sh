#!/usr/bin/env bash
# bin-bypass — splits binary files into 200MB fragments, reassembles them back.
# Usage:
#   bin-bypass.sh split <path_to_binary> [simple_vk_bypass]
#   bin-bypass.sh build <path_to_info.txt>

FRAGMENT_SIZE=209715200   # 200 MB
CAESAR_SHIFT=13

# Caesar encode/decode via Python (bash has no native byte math)
caesar_encode() {
    local in_file="$1" out_file="$2"
    python3 -c "
import sys
SHIFT = $CAESAR_SHIFT
data = open('$in_file','rb').read()
open('$out_file','wb').write(bytes((b + SHIFT) & 0xFF for b in data))
"
}

caesar_decode() {
    local in_file="$1" out_file="$2"
    python3 -c "
import sys
SHIFT = $CAESAR_SHIFT
data = open('$in_file','rb').read()
open('$out_file','wb').write(bytes((b - SHIFT) & 0xFF for b in data))
"
}

help_msg() {
    echo "To use this tool follow this syntax:"
    echo "bin-bypass.sh split <path_to_binary> [EXT] - to split binary"
    echo "bin-bypass.sh build <path_to_info.txt>     - to build up binary"
    echo "EXT can be:"
    echo "1. simple_vk_bypass - uses caesar shift to bypass vk.com automoderation of files"
    echo "other EXT maybe coming soon..."
}

do_split() {
    local file_path="$1"
    local enc_type="${2:-0}"

    if [[ ! -f "$file_path" ]]; then
        echo "[bin-bypass][x]: Cant reach file: $file_path" >&2
        return 1
    fi

    local filename
    filename=$(basename "$file_path")
    local file_size
    file_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path")

    echo "[bin-bypass][v]: filename: $filename"
    echo "[bin-bypass][v]: file size: $file_size bytes"

    local fragments_count=$(( (file_size + FRAGMENT_SIZE - 1) / FRAGMENT_SIZE ))
    echo "[bin-bypass][v]: binary file will be splited to $fragments_count fragments"
    echo "[bin-bypass][v]: this tool will generate next $((fragments_count + 1)) files:"
    echo "		[1] info.txt"

    {
        echo "f_name = $filename"
        echo "f_size = $file_size"
        echo "enc_type = $enc_type"
        echo "f_count = $fragments_count"
    } > info.txt

    local i=0
    while [[ $i -lt $fragments_count ]]; do
        local frag_name="f${i}.txt"
        echo "		[$((i + 2))] $frag_name"
        local offset=$(( i * FRAGMENT_SIZE ))
        dd if="$file_path" of="__tmp_frag__" bs=1 skip="$offset" count="$FRAGMENT_SIZE" 2>/dev/null
        if [[ "$enc_type" == "1" ]]; then
            caesar_encode "__tmp_frag__" "$frag_name"
            rm -f "__tmp_frag__"
        else
            mv "__tmp_frag__" "$frag_name"
        fi
        (( i++ ))
    done
}

do_build() {
    local info_path="$1"

    if [[ ! -f "$info_path" ]]; then
        echo "[bin-bypass][x]: cant reach info file \"$info_path\"" >&2
        return 1
    fi

    local filename file_size enc_type frag_count
    filename=$(grep  "^f_name"   "$info_path" | awk -F' = ' '{print $2}')
    file_size=$(grep "^f_size"   "$info_path" | awk -F' = ' '{print $2}')
    enc_type=$(grep  "^enc_type" "$info_path" | awk -F' = ' '{print $2}')
    frag_count=$(grep "^f_count" "$info_path" | awk -F' = ' '{print $2}')

    local all_ok=1
    for (( i=0; i<frag_count; i++ )); do
        local frag_name="f${i}.txt"
        printf "[bin-bypass]: checking file %s - " "$frag_name"
        if [[ -f "$frag_name" ]]; then
            echo "[v] file available"
        else
            echo "[x] cant reach this file"
            all_ok=0
        fi
    done

    if [[ $all_ok -eq 0 ]]; then
        echo "[bin-bypass][x]: missing fragments, aborting" >&2
        return 1
    fi

    echo "[bin-bypass][v]: starting reassembling of origin binary"
    : > "$filename"   # truncate / create output

    for (( i=0; i<frag_count; i++ )); do
        local frag_name="f${i}.txt"
        printf "[bin-bypass]: trying to process file \"%s\" - " "$frag_name"
        if [[ "$enc_type" == "1" ]]; then
            caesar_decode "$frag_name" "__dec_frag__"
            cat "__dec_frag__" >> "$filename"
            rm -f "__dec_frag__"
        else
            cat "$frag_name" >> "$filename"
        fi
        echo "[v]"
    done
}

# ── main ──────────────────────────────────────────────────────────────────────
CMD="${1:-}"

case "$CMD" in
    split)
        if [[ $# -lt 2 ]]; then
            echo "[bin-bypass][x]: syntax error" >&2; help_msg; exit 1
        fi
        FILE_PATH="$2"
        ENC=0
        if [[ $# -eq 3 ]]; then
            if [[ "$3" == "simple_vk_bypass" ]]; then
                ENC=1
                echo "[bin-bypass][v]: splitting origin file"
                echo "[bin-bypass][v]: EXT - \"$3\""
            else
                echo "[bin-bypass][x]: unrecoginzed EXT - \"$3\"" >&2; exit 1
            fi
        else
            echo "[bin-bypass][v]: splitting origin file"
            echo "[bin-bypass][!]: without EXT"
        fi
        do_split "$FILE_PATH" "$ENC"
        ;;
    build)
        if [[ $# -lt 2 ]]; then
            echo "[bin-bypass][x]: syntax error" >&2; help_msg; exit 1
        fi
        echo "[bin-bypass][v]: building origin file"
        echo "[bin-bypass][!]: without EXT (reads from info.txt)"
        do_build "$2"
        ;;
    "")
        help_msg
        ;;
    *)
        echo "[bin-bypass][x]: unrecoginzed CMD - \"$CMD\"" >&2
        help_msg; exit 1
        ;;
esac

echo "[bin-bypass][v]: tool ended work"
