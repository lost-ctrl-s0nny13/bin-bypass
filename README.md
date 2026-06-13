# bin-bypass

A CLI utility for splitting large binary files into **200 MB fragments** and reassembling them back. Designed to work around VK's file size limit when sharing executables or large binaries. Supports optional Caesar-shift encoding to bypass VK's automoderation.

Available in **5 implementations**: C, Python, Bash, PowerShell, and CMD.

---

## Features

- Split any binary file into ≤200 MB fragments
- Reassemble fragments back into the original file with byte-perfect accuracy
- Optional `simple_vk_bypass` mode — applies a Caesar shift (ROT-13) to each byte, bypassing VK automoderation
- Generates an `info.txt` manifest used during reassembly
- Cross-platform implementations

---

## Implementations

| File | Platform | Dependencies |
|------|----------|-------------|
| `src/main.c` + `src/tools.c` | Windows / Linux | GCC / CLANG |
| `bin_bypass.py` | Any (Python 3) | Python 3 |
| `bin_bypass.sh` | Linux / macOS | Bash |
| `bin_bypass.ps1` | Windows | PowerShell 5+ |
| `bin_bypass.cmd` | Windows | CMD, Python 3 |

---

## Usage

All implementations share the same interface:

### Split a binary file

```
bin-bypass split <path_to_binary> [EXT]
```

### Reassemble fragments

```
bin-bypass build <path_to_info.txt>
```

### EXT options

| EXT | Description |
|-----|-------------|
| *(none)* | No encoding, raw binary split |
| `simple_vk_bypass` | Applies Caesar shift (+13) to every byte before saving fragments |

---

## Examples

**Python**
```bash
python bin_bypass.py split ./myapp.exe simple_vk_bypass
python bin_bypass.py build ./info.txt
```

**Bash**
```bash
bash bin_bypass.sh split ./myapp simple_vk_bypass
bash bin_bypass.sh build ./info.txt
```

**PowerShell**
```powershell
.\bin_bypass.ps1 split .\myapp.exe simple_vk_bypass
.\bin_bypass.ps1 build .\info.txt
```

**CMD**
```cmd
bin_bypass.cmd split myapp.exe simple_vk_bypass
bin_bypass.cmd build info.txt
```

**C (build first)**
```bash
gcc src/main.c src/tools.c -o bin-bypass
./bin-bypass split myapp simple_vk_bypass
./bin-bypass build info.txt
```

---

## How it works

### Split

1. Opens the source binary and reads its size
2. Calculates the number of 200 MB fragments needed
3. Writes an `info.txt` manifest:
    ```
    f_name = myapp.exe
    f_size = 524288000
    enc_type = 1
    f_count = 3
    ```
4. Reads each chunk sequentially, optionally encodes it, and writes it as `f0.txt`, `f1.txt`, `f2.txt`, ...

### Build

1. Parses `info.txt` to get the original filename, size, encoding type, and fragment count
2. Checks that all fragment files (`f0.txt` … `fN.txt`) are present
3. Reads each fragment in order, decodes if needed, and appends to the output file

### `simple_vk_bypass` encoding

Each byte is shifted by +13 on encode and −13 on decode (wrapping at 0–255). This is enough to prevent VK's content scanner from recognizing executable file signatures.

```
encode: byte = (byte + 13) & 0xFF
decode: byte = (byte - 13) & 0xFF
```

---

## Output files

After running `split`, the tool generates:

```
info.txt      ← manifest (required for build)
f0.txt        ← fragment 0
f1.txt        ← fragment 1
...
fN.txt        ← last fragment
```

All files should be kept together in the same directory before running `build`.

---

## Building the C version

**Windows (MSVC / MinGW)**
```bash
gcc src/main.c src/tools.c -o bin-bypass.exe
```

**Linux**
> Change `#define _WINDOWS_BUILD` to `#define _LINUX_BUILD` in `src/config.h`, then:
```bash
gcc src/main.c src/tools.c -o bin-bypass
```

> Requires a 64-bit system (`sizeof(void*) == 8` is enforced at compile time).

---

## Project structure

```
bin-bypass/
├── src/
│   ├── config.h          # Build target selection (Windows / Linux)
│   ├── tools.h           # Function declarations
│   ├── tools.c           # Core logic (split, build, encode)
│   └── main.c            # CLI entry point
├── bin_bypass.py         # Python implementation
├── bin_bypass.sh         # Bash implementation
├── bin_bypass.ps1        # PowerShell implementation
├── bin_bypass.cmd        # CMD implementation
└── README.md
```

---

## License

MIT
