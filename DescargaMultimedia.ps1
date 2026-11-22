$ErrorActionPreference = "Stop"
$exe = Join-Path $PSScriptRoot "DescargaMultimedia.exe"
$fuentes = "Programa.cs", "Ventana.cs", "interfaz.html", "Descargar.ps1", "Compilar.ps1"
if (-not (Test-Path -LiteralPath $exe) -or ($fuentes | Where-Object {
    (Get-Item -LiteralPath (Join-Path $PSScriptRoot $_)).LastWriteTimeUtc -gt (Get-Item -LiteralPath $exe).LastWriteTimeUtc
})) {
    & (Join-Path $PSScriptRoot "Compilar.ps1") | Out-Null
}
Start-Process -FilePath $exe
