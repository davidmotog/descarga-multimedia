Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:job = $null
$script:logFile = $null
$script:lastContent = ""

function Show-Error {
    param([string]$msg)

    [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Show-Info {
    param([string]$msg)

    [System.Windows.Forms.MessageBox]::Show(
        $msg,
        "Información",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "YouTube a MP3 / MP4"
$form.Size = New-Object System.Drawing.Size(760, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$urlLabel = New-Object System.Windows.Forms.Label
$urlLabel.Text = "Enlace de YouTube:"
$urlLabel.Location = New-Object System.Drawing.Point(20, 20)
$urlLabel.Size = New-Object System.Drawing.Size(200, 25)
$form.Controls.Add($urlLabel)

$urlBox = New-Object System.Windows.Forms.TextBox
$urlBox.Location = New-Object System.Drawing.Point(20, 45)
$urlBox.Size = New-Object System.Drawing.Size(700, 25)
$form.Controls.Add($urlBox)

$folderLabel = New-Object System.Windows.Forms.Label
$folderLabel.Text = "Carpeta de salida:"
$folderLabel.Location = New-Object System.Drawing.Point(20, 85)
$folderLabel.Size = New-Object System.Drawing.Size(200, 25)
$form.Controls.Add($folderLabel)

$folderBox = New-Object System.Windows.Forms.TextBox
$folderBox.Location = New-Object System.Drawing.Point(20, 110)
$folderBox.Size = New-Object System.Drawing.Size(590, 25)
$folderBox.Text = "$env:USERPROFILE\Downloads"
$form.Controls.Add($folderBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = "Elegir..."
$browseButton.Location = New-Object System.Drawing.Point(620, 108)
$browseButton.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($browseButton)

$downloadButtonMP3 = New-Object System.Windows.Forms.Button
$downloadButtonMP3.Text = "Descargar MP3"
$downloadButtonMP3.Location = New-Object System.Drawing.Point(20, 155)
$downloadButtonMP3.Size = New-Object System.Drawing.Size(160, 35)
$form.Controls.Add($downloadButtonMP3)

$downloadButtonMP4 = New-Object System.Windows.Forms.Button
$downloadButtonMP4.Text = "Descargar MP4"
$downloadButtonMP4.Location = New-Object System.Drawing.Point(200, 155)
$downloadButtonMP4.Size = New-Object System.Drawing.Size(160, 35)
$form.Controls.Add($downloadButtonMP4)

$openFolderButton = New-Object System.Windows.Forms.Button
$openFolderButton.Text = "Abrir carpeta"
$openFolderButton.Location = New-Object System.Drawing.Point(380, 155)
$openFolderButton.Size = New-Object System.Drawing.Size(160, 35)
$form.Controls.Add($openFolderButton)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 210)
$logBox.Size = New-Object System.Drawing.Size(700, 240)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 700

function Set-ButtonsEnabled {
    param([bool]$enabled)

    $downloadButtonMP3.Enabled = $enabled
    $downloadButtonMP4.Enabled = $enabled
    $browseButton.Enabled = $enabled
}

function Start-Download {
    param(
        [ValidateSet("mp3", "mp4")]
        [string]$mode
    )

    if ($script:job -and $script:job.State -eq "Running") {
        Show-Error "Ya hay una descarga en curso."
        return
    }

    $url = $urlBox.Text.Trim()
    $folder = $folderBox.Text.Trim()

    if ([string]::IsNullOrWhiteSpace($url)) {
        Show-Error "Pega primero un enlace de YouTube."
        return
    }

    if ([string]::IsNullOrWhiteSpace($folder)) {
        Show-Error "Elige una carpeta de salida."
        return
    }

    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
    }

    $script:logFile = Join-Path $env:TEMP ("yt-dlp-gui-" + [guid]::NewGuid().ToString() + ".log")
    $script:lastContent = ""

    $modeText = $mode.ToUpper()

    $logBox.Clear()
    $logBox.AppendText("Modo: $modeText`r`n")
    $logBox.AppendText("Descargando en: $folder`r`n")
    $logBox.AppendText("URL: $url`r`n`r`n")
    $logBox.AppendText("Comprobando yt-dlp y ffmpeg...`r`n")

    Set-ButtonsEnabled $false

    $script:job = Start-Job -ArgumentList $url, $folder, $script:logFile, $mode -ScriptBlock {
        param($Url, $Folder, $LogFile, $Mode)

        function Write-Log {
            param([string]$Text = "")
            $Text | Out-File -FilePath $LogFile -Encoding utf8 -Append
        }

        function Refresh-Path {
            $paths = @()

            $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")

            foreach ($p in @($machinePath, $userPath, $processPath)) {
                if (-not [string]::IsNullOrWhiteSpace($p)) {
                    $paths += $p.Split(";") | Where-Object {
                        -not [string]::IsNullOrWhiteSpace($_)
                    }
                }
            }

            $uniquePaths = $paths | Select-Object -Unique
            [Environment]::SetEnvironmentVariable("Path", ($uniquePaths -join ";"), "Process")
        }

        function Test-CommandExists {
            param([string]$CommandName)

            Refresh-Path
            return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
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
                    $_.ToString() | Out-File -FilePath $LogFile -Encoding utf8 -Append
                }

            return $LASTEXITCODE
        }

        function Install-WithWinget {
            param(
                [string]$PackageId,
                [string]$ProgramName
            )

            Refresh-Path

            if (-not (Test-CommandExists "winget")) {
                Write-Log "ERROR: No encuentro winget."
                Write-Log "No puedo instalar dependencias automáticamente."
                Write-Log "Instala manualmente yt-dlp y ffmpeg."
                return $false
            }

            Write-Log ("No encuentro {0}. Intentando instalar automáticamente..." -f $ProgramName)
            Write-Log ("Paquete winget: {0}" -f $PackageId)
            Write-Log ""

            $argsSilent = @(
                "install",
                "-e",
                "--id", $PackageId,
                "--source", "winget",
                "--silent",
                "--accept-package-agreements",
                "--accept-source-agreements",
                "--disable-interactivity"
            )

            $installCode = Invoke-LoggedProcess -FilePath "winget" -Arguments $argsSilent

            if ($installCode -ne 0) {
                Write-Log ""
                Write-Log ("La instalación silenciosa de {0} falló con código {1}." -f $ProgramName, $installCode)
                Write-Log "Reintentando sin modo silencioso..."
                Write-Log ""

                $argsNormal = @(
                    "install",
                    "-e",
                    "--id", $PackageId,
                    "--source", "winget",
                    "--accept-package-agreements",
                    "--accept-source-agreements"
                )

                $installCode = Invoke-LoggedProcess -FilePath "winget" -Arguments $argsNormal
            }

            Write-Log ""
            Write-Log ("Código de instalación de {0}: {1}" -f $ProgramName, $installCode)

            Start-Sleep -Seconds 2
            Refresh-Path

            if ($installCode -ne 0) {
                Write-Log ("ERROR: No se pudo instalar {0} automáticamente." -f $ProgramName)
                return $false
            }

            Write-Log ("{0} instalado correctamente." -f $ProgramName)
            return $true
        }

        function Ensure-Dependencies {
            Refresh-Path

            if (-not (Test-CommandExists "yt-dlp")) {
                $okYtdlp = Install-WithWinget -PackageId "yt-dlp.yt-dlp" -ProgramName "yt-dlp"

                if (-not $okYtdlp) {
                    return $false
                }
            } else {
                Write-Log "yt-dlp encontrado."
            }

            Refresh-Path

            if (-not (Test-CommandExists "ffmpeg")) {
                $okFfmpeg = Install-WithWinget -PackageId "Gyan.FFmpeg" -ProgramName "ffmpeg"

                if (-not $okFfmpeg) {
                    return $false
                }
            } else {
                Write-Log "ffmpeg encontrado."
            }

            Refresh-Path

            if (-not (Test-CommandExists "yt-dlp")) {
                Write-Log "ERROR: yt-dlp se instaló, pero esta sesión todavía no lo encuentra."
                Write-Log "Cierra y vuelve a abrir el programa, o reinicia Windows."
                return $false
            }

            if (-not (Test-CommandExists "ffmpeg")) {
                Write-Log "ERROR: ffmpeg se instaló, pero esta sesión todavía no lo encuentra."
                Write-Log "Cierra y vuelve a abrir el programa, o reinicia Windows."
                return $false
            }

            Write-Log ""
            Write-Log "Dependencias listas."
            Write-Log ""

            return $true
        }

        $outputTemplate = Join-Path $Folder "%(title)s.%(ext)s"

        Write-Log "----------------------------------------"
        Write-Log ("Fecha: {0}" -f (Get-Date))
        Write-Log ("URL: {0}" -f $Url)
        Write-Log ("Salida: {0}" -f $outputTemplate)
        Write-Log ("Modo: {0}" -f $Mode)
        Write-Log "----------------------------------------"
        Write-Log ""

        $depsOk = Ensure-Dependencies

        if (-not $depsOk) {
            Write-Log ""
            Write-Log "ERROR: Faltan dependencias. No puedo continuar."
            exit 50
        }

        if ($Mode -eq "mp3") {
            $ytArgs = @(
                "--newline",
                "--no-playlist",
                "--windows-filenames",
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", "0",
                "-o", $outputTemplate,
                $Url
            )

            $exitCode = Invoke-LoggedProcess -FilePath "yt-dlp" -Arguments $ytArgs
        }
        elseif ($Mode -eq "mp4") {
            $ytArgs = @(
                "--newline",
                "--no-playlist",
                "--windows-filenames",
                "-f", "bv*[ext=mp4]+ba[ext=m4a]/b[ext=mp4]/bv*+ba/best",
                "--merge-output-format", "mp4",
                "--recode-video", "mp4",
                "-o", $outputTemplate,
                $Url
            )

            $exitCode = Invoke-LoggedProcess -FilePath "yt-dlp" -Arguments $ytArgs
        }

        Write-Log ""

        if ($exitCode -eq 0) {
            if ($Mode -eq "mp3") {
                Write-Log "FINALIZADO: MP3 creado correctamente."
            }
            elseif ($Mode -eq "mp4") {
                Write-Log "FINALIZADO: MP4 creado correctamente."
            }
        } else {
            Write-Log ("ERROR: yt-dlp terminó con código {0}." -f $exitCode)
        }
    }

    $timer.Start()
}

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Elige dónde guardar el archivo"

    if (Test-Path $folderBox.Text) {
        $dialog.SelectedPath = $folderBox.Text
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $folderBox.Text = $dialog.SelectedPath
    }
})

$downloadButtonMP3.Add_Click({
    Start-Download "mp3"
})

$downloadButtonMP4.Add_Click({
    Start-Download "mp4"
})

$openFolderButton.Add_Click({
    $folder = $folderBox.Text.Trim()

    if (Test-Path $folder) {
        Start-Process explorer.exe -ArgumentList "`"$folder`""
    } else {
        Show-Error "La carpeta no existe."
    }
})

$timer.Add_Tick({
    if ($script:logFile -and (Test-Path $script:logFile)) {
        $content = Get-Content $script:logFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

        if ($content -ne $script:lastContent) {
            $script:lastContent = $content
            $logBox.Text = $content
            $logBox.SelectionStart = $logBox.Text.Length
            $logBox.ScrollToCaret()
        }
    }

    if ($script:job -and ($script:job.State -in @("Completed", "Failed", "Stopped"))) {
        $timer.Stop()

        Receive-Job $script:job -ErrorAction SilentlyContinue | Out-Null
        Remove-Job $script:job -Force -ErrorAction SilentlyContinue

        $script:job = $null

        Set-ButtonsEnabled $true

        [System.Media.SystemSounds]::Asterisk.Play()
    }
})

$form.Add_FormClosing({
    if ($script:job -and $script:job.State -eq "Running") {
        $answer = [System.Windows.Forms.MessageBox]::Show(
            "Hay una descarga en curso. ¿Quieres cerrar igualmente?",
            "Descarga activa",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )

        if ($answer -eq [System.Windows.Forms.DialogResult]::No) {
            $_.Cancel = $true
        } else {
            Stop-Job -Job $script:job -ErrorAction SilentlyContinue
            Remove-Job -Job $script:job -Force -ErrorAction SilentlyContinue
        }
    }
})

$form.Add_Shown({
    $urlBox.Focus()
})

[void]$form.ShowDialog()