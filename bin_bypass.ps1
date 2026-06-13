<#
.SYNOPSIS
    bin-bypass — splits binary files into 200MB fragments for VK upload, reassembles them back.
.EXAMPLE
    .\bin-bypass.ps1 split .\file.exe
    .\bin-bypass.ps1 split .\file.exe simple_vk_bypass
    .\bin-bypass.ps1 build .\info.txt
#>

param(
    [Parameter(Position=0)] [string]$Command  = "",
    [Parameter(Position=1)] [string]$Argument = "",
    [Parameter(Position=2)] [string]$Ext      = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$FRAGMENT_SIZE  = 209715200   # 200 MB
$CAESAR_SHIFT   = 13

# ── helpers ──────────────────────────────────────────────────────────────────

function Show-Help {
    Write-Host "To use this tool follow this syntax:"
    Write-Host "bin-bypass.ps1 split <path_to_binary> [EXT] - to split binary"
    Write-Host "bin-bypass.ps1 build <path_to_info.txt>     - to build up binary"
    Write-Host "EXT can be:"
    Write-Host "1. simple_vk_bypass - uses caesar shift to bypass vk.com automoderation of files"
    Write-Host "other EXT maybe coming soon..."
}

function Invoke-CaesarEncode([byte[]]$Data) {
    $result = [byte[]]::new($Data.Length)
    for ($i = 0; $i -lt $Data.Length; $i++) {
        $result[$i] = [byte](($Data[$i] + $CAESAR_SHIFT) -band 0xFF)
    }
    return $result
}

function Invoke-CaesarDecode([byte[]]$Data) {
    $result = [byte[]]::new($Data.Length)
    for ($i = 0; $i -lt $Data.Length; $i++) {
        $result[$i] = [byte](($Data[$i] - $CAESAR_SHIFT + 256) -band 0xFF)
    }
    return $result
}

# ── split ─────────────────────────────────────────────────────────────────────

function Invoke-Split([string]$FilePath, [int]$EncType) {
    if (-not (Test-Path $FilePath -PathType Leaf)) {
        Write-Error "[bin-bypass][x]: Cant reach file: $FilePath"
        return
    }

    $filename  = Split-Path $FilePath -Leaf
    $fileSize  = (Get-Item $FilePath).Length

    Write-Host "[bin-bypass][v]: filename: $filename"
    Write-Host "[bin-bypass][v]: file size: $fileSize bytes"

    $fragCount = [Math]::Ceiling($fileSize / $FRAGMENT_SIZE)
    Write-Host "[bin-bypass][v]: binary file will be splited to $fragCount fragments"
    Write-Host "[bin-bypass][v]: this tool will generate next $($fragCount + 1) files:"
    Write-Host "`t`t[1] info.txt"

    Set-Content -Path "info.txt" -Encoding UTF8 -Value @"
f_name = $filename
f_size = $fileSize
enc_type = $EncType
f_count = $fragCount
"@

    $stream = [System.IO.File]::OpenRead($FilePath)
    try {
        $chunk = [byte[]]::new($FRAGMENT_SIZE)
        for ($i = 0; $i -lt $fragCount; $i++) {
            $fragName = "f${i}.txt"
            Write-Host "`t`t[$($i + 2)] $fragName"
            $read = $stream.Read($chunk, 0, $FRAGMENT_SIZE)
            $data = $chunk[0..($read - 1)]
            if ($EncType -eq 1) { $data = Invoke-CaesarEncode $data }
            [System.IO.File]::WriteAllBytes($fragName, $data)
        }
    } finally {
        $stream.Close()
    }
}

# ── build ─────────────────────────────────────────────────────────────────────

function Invoke-Build([string]$InfoPath) {
    if (-not (Test-Path $InfoPath -PathType Leaf)) {
        Write-Error "[bin-bypass][x]: cant reach info file `"$InfoPath`""
        return
    }

    $info = @{}
    Get-Content $InfoPath | ForEach-Object {
        if ($_ -match "^(\S+)\s+=\s+(.+)$") { $info[$Matches[1]] = $Matches[2] }
    }
    $filename  = $info["f_name"]
    $encType   = [int]$info["enc_type"]
    $fragCount = [int]$info["f_count"]

    $allOk = $true
    for ($i = 0; $i -lt $fragCount; $i++) {
        $frag = "f${i}.txt"
        Write-Host -NoNewline "[bin-bypass]: checking file $frag - "
        if (Test-Path $frag -PathType Leaf) {
            Write-Host "[v] file available"
        } else {
            Write-Host "[x] cant reach this file"
            $allOk = $false
        }
    }

    if (-not $allOk) {
        Write-Error "[bin-bypass][x]: missing fragments, aborting"
        return
    }

    Write-Host "[bin-bypass][v]: starting reassembling of origin binary"
    $outStream = [System.IO.File]::OpenWrite($filename)
    try {
        for ($i = 0; $i -lt $fragCount; $i++) {
            $frag = "f${i}.txt"
            Write-Host -NoNewline "[bin-bypass]: trying to process file `"$frag`" - "
            $data = [System.IO.File]::ReadAllBytes($frag)
            if ($encType -eq 1) { $data = Invoke-CaesarDecode $data }
            $outStream.Write($data, 0, $data.Length)
            Write-Host "[v]"
        }
    } finally {
        $outStream.Close()
    }
}

# ── main ──────────────────────────────────────────────────────────────────────

switch ($Command) {
    "split" {
        if (-not $Argument) { Write-Error "[bin-bypass][x]: syntax error"; Show-Help; exit 1 }
        $encType = 0
        if ($Ext -eq "simple_vk_bypass") {
            $encType = 1
            Write-Host "[bin-bypass][v]: splitting origin file"
            Write-Host "[bin-bypass][v]: EXT - `"$Ext`""
        } elseif ($Ext -ne "") {
            Write-Error "[bin-bypass][x]: unrecoginzed EXT - `"$Ext`""; exit 1
        } else {
            Write-Host "[bin-bypass][v]: splitting origin file"
            Write-Host "[bin-bypass][!]: without EXT"
        }
        Invoke-Split $Argument $encType
    }
    "build" {
        if (-not $Argument) { Write-Error "[bin-bypass][x]: syntax error"; Show-Help; exit 1 }
        Write-Host "[bin-bypass][v]: building origin file"
        Write-Host "[bin-bypass][!]: without EXT (reads from info.txt)"
        Invoke-Build $Argument
    }
    "" {
        Show-Help
    }
    default {
        Write-Host "[bin-bypass][x]: unrecoginzed CMD - `"$Command`"" -ForegroundColor Red
        Show-Help; exit 1
    }
}

Write-Host "[bin-bypass][v]: tool ended work"
