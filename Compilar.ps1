$ErrorActionPreference = "Stop"
$sourcePath = Join-Path $PSScriptRoot "DescargaMultimedia.ps1"
$source = [IO.File]::ReadAllText($sourcePath)
if ($source -notmatch '(?m)^\$appVersion = \[version\]"(1\.\d{4}\.\d{1,2}\.\d{1,2})"\s*$') {
    throw "Falta la versión 1.año.mes.día en DescargaMultimedia.ps1."
}
$build = @{
    InputFile = $sourcePath
    OutputFile = Join-Path $PSScriptRoot "DescargaMultimedia.exe"
    NoConsole = $true
    STA = $true
    Title = "Descarga Multimedia"
    Product = "Descarga Multimedia"
    Description = "Descarga de audio MP3 y vídeo MP4 con yt-dlp y FFmpeg"
    Version = $Matches[1]
}
Invoke-PS2EXE @build
