param($Url, $Folder, $LogFile, $Mode, $AllowInstall, $ResultFile)

function Write-Log {
    param([string]$Text = "")
    $Text | Out-File -LiteralPath $LogFile -Encoding utf8 -Append
}

function Refresh-Path {
    $paths = foreach ($scope in @("Process", "User", "Machine")) {
        [Environment]::GetEnvironmentVariable("Path", $scope) -split ";" | Where-Object { $_ }
    }
    $env:Path = ($paths | Select-Object -Unique) -join ";"
}

function Test-CommandExists {
    param([string]$CommandName)
    return [bool](Get-Command $CommandName -CommandType Application -ErrorAction SilentlyContinue)
}

function Invoke-LoggedProcess {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    Write-Log ("Ejecutando: {0} {1}" -f $FilePath, ($Arguments -join " "))
    Write-Log ""

    & $FilePath @Arguments *>&1 |
        ForEach-Object {
            Write-Log $_.ToString()
        }

    return $LASTEXITCODE
}

function Ensure-Dependency {
    param([string]$CommandName, [string]$PackageId)

    if (Test-CommandExists $CommandName) {
        Write-Log ("Disponible: " + $CommandName)
        return $true
    }

    if (-not $AllowInstall -or -not (Test-CommandExists "winget")) {
        Write-Log ("Falta {0}. Puedes instalarlo con: winget install --id {1} --exact" -f $CommandName, $PackageId)
        return $false
    }

    Write-Log ("Instalando " + $PackageId)
    $installArgs = @("install", "--id", $PackageId, "--exact", "--source", "winget",
        "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity")
    $code = Invoke-LoggedProcess -FilePath "winget" -Arguments $installArgs
    Refresh-Path
    if (-not (Test-CommandExists $CommandName)) {
        Write-Log ("No se encuentra {0} después de ejecutar WinGet (código {1})." -f $CommandName, $code)
        return $false
    }
    return $true
}

$outputTemplate = "%(title).140B [%(id)s].%(ext)s"

Write-Log "----------------------------------------"
Write-Log ("Fecha: {0}" -f (Get-Date))
Write-Log ("URL: {0}" -f $Url)
Write-Log ("Salida: {0}" -f $outputTemplate)
Write-Log ("Modo: {0}" -f $Mode)
Write-Log "----------------------------------------"
Write-Log ""

Refresh-Path
if (-not (Ensure-Dependency "yt-dlp" "yt-dlp.yt-dlp")) { return }
if (-not (Ensure-Dependency "ffmpeg" "Gyan.FFmpeg")) { return }
if (([uri]$Url).Host -match '(^|\.)(youtube\.com|youtu\.be|youtube-nocookie\.com)$') {
    if (-not (Ensure-Dependency "deno" "DenoLand.Deno")) { return }
}

$ytArgs = @("--newline", "--no-playlist", "--windows-filenames", "--no-overwrites",
    "-P", $Folder, "-o", $outputTemplate)
if ($Mode -eq "mp3") {
    $ytArgs += @("-x", "--audio-format", "mp3", "--audio-quality", "0")
} else {
    $ytArgs += @("-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/best",
        "--merge-output-format", "mp4", "--recode-video", "mp4")
}

$ytArgs += @("--no-simulate", "--progress", "--progress-template", "download:DM_PROGRESS %(progress._percent_str)s",
    "--print", "post_process:DM_CONVERT %(ext)s", "--print-to-file", "after_move:filepath", $ResultFile,
    "--encoding", ("cp" + [Console]::OutputEncoding.CodePage), "--", $Url)
$version = & yt-dlp --version
Write-Log ("Versión de yt-dlp: " + $version)
$exitCode = Invoke-LoggedProcess -FilePath "yt-dlp" -Arguments $ytArgs
if ($exitCode -ne 0 -and (Select-String -LiteralPath $LogFile -Pattern '^(ERROR|WARNING):.*\bHTTP Error 403\b' -Quiet)) {
    Write-Log "El servidor ha rechazado la descarga (HTTP 403)."
    if ($AllowInstall -and (Test-CommandExists "winget")) {
        Write-Log "Buscando una actualización de yt-dlp con WinGet..."
        $upgradeArgs = @("upgrade", "--id", "yt-dlp.yt-dlp", "--exact", "--source", "winget",
            "--accept-package-agreements", "--accept-source-agreements", "--disable-interactivity")
        $upgradeCode = Invoke-LoggedProcess -FilePath "winget" -Arguments $upgradeArgs
        Refresh-Path
        if (Test-CommandExists "yt-dlp") {
            $currentVersion = & yt-dlp --version
            if ($LASTEXITCODE -eq 0 -and $currentVersion -and $currentVersion -ne $version) {
                Write-Log ("yt-dlp actualizado a {0}. Reintentando la descarga..." -f $currentVersion)
                $exitCode = Invoke-LoggedProcess -FilePath "yt-dlp" -Arguments $ytArgs
            } else {
                Write-Log ("Sigue activa la versión {0}. WinGet terminó con código {1}." -f $currentVersion, $upgradeCode)
            }
        } else {
            Write-Log "Tras la actualización, Windows no encuentra yt-dlp. Vuelve a abrir el programa."
        }
    } elseif (-not $AllowInstall -and (Test-CommandExists "winget")) {
        Write-Log "Marca la casilla de WinGet y vuelve a pulsar Descargar para permitir que se actualice yt-dlp si se repite el 403."
    } else {
        Write-Log "Actualiza yt-dlp con el mismo método que usaste para instalarlo y vuelve a intentar la descarga."
    }
}
Write-Log ""

if ($exitCode -eq 0) {
    if ($Mode -eq "mp3") {
        Write-Log "FINALIZADO: MP3 disponible en la carpeta de salida."
    }
    elseif ($Mode -eq "mp4") {
        Write-Log "FINALIZADO: MP4 disponible en la carpeta de salida."
    }
} else {
    Write-Log ("ERROR: yt-dlp terminó con código {0}." -f $exitCode)
}
