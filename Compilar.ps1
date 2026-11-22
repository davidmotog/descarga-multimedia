param([string]$Salida = (Join-Path $PSScriptRoot "DescargaMultimedia.exe"))
$ErrorActionPreference = "Stop"
$sdkVersion = "1.0.4370.26"
$sdkHash = "1C0DACAC84B70109B3FD42F90C53A0BA942ABC3A87590D7A4E0CCD86E4A06CF4"
$buildDir = Join-Path ([IO.Path]::GetTempPath()) ("descarga-build-" + [guid]::NewGuid().ToString("N"))
[void][IO.Directory]::CreateDirectory($buildDir)
try {
    $zip = Join-Path $buildDir "webview2.zip"
    $package = "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$sdkVersion/microsoft.web.webview2.$sdkVersion.nupkg"
    Invoke-WebRequest -UseBasicParsing -Uri $package -OutFile $zip
    if ((Get-FileHash -LiteralPath $zip).Hash -ne $sdkHash) { throw "La suma SHA-256 del SDK WebView2 no coincide." }
    Expand-Archive -LiteralPath $zip -DestinationPath $buildDir
    $lib = Join-Path $buildDir "lib\net462"
    $csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) "csc.exe"
    $binary = Join-Path $buildDir "DescargaMultimedia.exe"
    $opciones = @("/nologo", "/target:winexe", "/platform:anycpu", "/optimize+", "/utf8output", "/codepage:65001", "/out:$binary",
        "/reference:System.Windows.Forms.dll", "/reference:System.Drawing.dll", "/reference:System.Net.Http.dll",
        "/reference:System.Web.Extensions.dll", ("/reference:" + [Management.Automation.PowerShell].Assembly.Location))
    foreach ($name in @("Microsoft.Web.WebView2.Core.dll", "Microsoft.Web.WebView2.WinForms.dll")) {
        $opciones += "/reference:$lib\$name", "/resource:$lib\$name,$name"
    }
    foreach ($arch in @("x86", "x64", "arm64")) {
        $opciones += "/resource:$buildDir\build\native\$arch\WebView2Loader.dll,loader.$arch"
    }
    foreach ($name in @("LICENSE.txt", "NOTICE.txt")) { $opciones += "/resource:$buildDir\$name,WebView2.$name" }
    foreach ($name in @("interfaz.html", "Descargar.ps1")) { $opciones += "/resource:$PSScriptRoot\$name,$name" }
    & $csc @opciones "$PSScriptRoot\Programa.cs" "$PSScriptRoot\Ventana.cs"
    if ($LASTEXITCODE -ne 0) { throw "Error al compilar el ejecutable." }
    Copy-Item -LiteralPath $binary -Destination $Salida -Force
    Get-Item -LiteralPath $Salida
} finally {
    $expected = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetFileName($buildDir))
    if ([IO.Path]::GetFullPath($buildDir) -eq [IO.Path]::GetFullPath($expected) -and
        [IO.Path]::GetFileName($buildDir) -match '^descarga-build-[0-9a-f]{32}$') {
        Remove-Item -LiteralPath $buildDir -Recurse -Force
    }
}
