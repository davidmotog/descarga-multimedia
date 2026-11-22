$ErrorActionPreference = "Stop"
$build = @{
    InputFile = Join-Path $PSScriptRoot "DescargaMultimedia.ps1"
    OutputFile = Join-Path $PSScriptRoot "DescargaMultimedia.exe"
    NoConsole = $true
    STA = $true
    Title = "Descarga Multimedia"
    Product = "Descarga Multimedia"
    Description = "Descarga de audio MP3 y vídeo MP4 con yt-dlp y FFmpeg"
    Version = "1.0.1.0"
}
Invoke-PS2EXE @build
