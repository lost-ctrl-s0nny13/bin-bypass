@echo off
:: bin-bypass.cmd — splits binary files into 200MB fragments, reassembles them back.
:: Usage:
::   bin-bypass.cmd split <path_to_binary> [simple_vk_bypass]
::   bin-bypass.cmd build <path_to_info.txt>
::
:: NOTE: CMD has no native binary math, so Python 3 is used for Caesar encode/decode
::       and for splitting/joining large binary files accurately.
::       Python 3 must be installed and available as "python" in PATH.

setlocal EnableDelayedExpansion

set "CMD_ARG=%~1"
set "FILE_ARG=%~2"
set "EXT_ARG=%~3"

if "%CMD_ARG%"=="" goto :help

if /I "%CMD_ARG%"=="split" goto :do_split
if /I "%CMD_ARG%"=="build" goto :do_build

echo [bin-bypass][x]: unrecoginzed CMD - "%CMD_ARG%"
goto :help

:: ─── SPLIT ────────────────────────────────────────────────────────────────────
:do_split
if "%FILE_ARG%"=="" (
    echo [bin-bypass][x]: syntax error
    goto :help
)
if not exist "%FILE_ARG%" (
    echo [bin-bypass][x]: Cant reach file: %FILE_ARG%
    goto :end
)

set "ENC_TYPE=0"
if "%EXT_ARG%"=="simple_vk_bypass" (
    set "ENC_TYPE=1"
    echo [bin-bypass][v]: splitting origin file
    echo [bin-bypass][v]: EXT - "%EXT_ARG%"
) else if NOT "%EXT_ARG%"=="" (
    echo [bin-bypass][x]: unrecoginzed EXT - "%EXT_ARG%"
    goto :end
) else (
    echo [bin-bypass][v]: splitting origin file
    echo [bin-bypass][!]: without EXT
)

python -c ^
"import sys, os; ^
FRAG=10485760; SHIFT=13; ^
path=r'%FILE_ARG%'; ^
filename=os.path.basename(path); ^
fsize=os.path.getsize(path); ^
enc=%ENC_TYPE%; ^
count=(fsize+FRAG-1)//FRAG; ^
print(f'[bin-bypass][v]: filename: {filename}'); ^
print(f'[bin-bypass][v]: file size: {fsize} bytes'); ^
print(f'[bin-bypass][v]: binary file will be splited to {count} fragments'); ^
print(f'[bin-bypass][v]: this tool will generate next {count+1} files:'); ^
print('\t\t[1] info.txt'); ^
open('info.txt','w').write(f'f_name = {filename}\nf_size = {fsize}\nenc_type = {enc}\nf_count = {count}'); ^
src=open(path,'rb'); ^
[( ^
    chunk:=bytearray(src.read(FRAG)), ^
    enc_chunk:=bytes((b+SHIFT)&0xFF for b in chunk) if enc else bytes(chunk), ^
    print(f'\t\t[{i+2}] f{i}.txt'), ^
    open(f'f{i}.txt','wb').write(enc_chunk) ^
) for i in range(count)]; ^
src.close()"

goto :end

:: ─── BUILD ────────────────────────────────────────────────────────────────────
:do_build
if "%FILE_ARG%"=="" (
    echo [bin-bypass][x]: syntax error
    goto :help
)
if not exist "%FILE_ARG%" (
    echo [bin-bypass][x]: cant reach info file "%FILE_ARG%"
    goto :end
)

echo [bin-bypass][v]: building origin file
echo [bin-bypass][!]: without EXT (reads from info.txt)

python -c ^
"import sys, os; ^
SHIFT=13; ^
info={}; ^
[info.update({k.strip():v.strip()}) for line in open(r'%FILE_ARG%') for k,_,v in [line.partition('=')]]; ^
filename=info['f_name']; fsize=int(info['f_size']); enc=int(info['enc_type']); count=int(info['f_count']); ^
ok=True; ^
[( ^
    print(f'[bin-bypass]: checking file f{i}.txt - ', end=''), ^
    print('[v] file available') if os.path.isfile(f'f{i}.txt') else (print('[x] cant reach this file'), setattr(sys.modules[__name__],'ok',False)) ^
) for i in range(count)]; ^
(print('[bin-bypass][x]: missing fragments, aborting') or sys.exit(1)) if not ok else None; ^
print('[bin-bypass][v]: starting reassembling of origin binary'); ^
out=open(filename,'wb'); ^
[( ^
    print(f'[bin-bypass]: trying to process file \"f{i}.txt\" - ', end=''), ^
    chunk:=bytearray(open(f'f{i}.txt','rb').read()), ^
    out.write(bytes((b-SHIFT)&0xFF for b in chunk) if enc else bytes(chunk)), ^
    print('[v]') ^
) for i in range(count)]; ^
out.close()"

goto :end

:: ─── HELP ─────────────────────────────────────────────────────────────────────
:help
echo To use this tool follow this syntax:
echo bin-bypass.cmd split ^<path_to_binary^> [EXT] - to split binary
echo bin-bypass.cmd build ^<path_to_info.txt^>     - to build up binary
echo EXT can be:
echo 1. simple_vk_bypass - uses caesar shift to bypass vk.com automoderation of files
echo other EXT maybe coming soon...

:end
echo [bin-bypass][v]: tool ended work
endlocal
