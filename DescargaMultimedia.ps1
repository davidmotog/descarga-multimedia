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

$form = New-Object System.Windows.Forms.Form
$form.Text = "Descarga Multimedia"
$form.Size = New-Object System.Drawing.Size(760, 520)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$urlLabel = New-Object System.Windows.Forms.Label
$urlLabel.Text = "Enlace del vídeo o audio:"
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

$installBox = New-Object System.Windows.Forms.CheckBox
$installBox.Text = "Permitir que WinGet instale herramientas y actualice yt-dlp si hay un error 403"
$installBox.Location = New-Object System.Drawing.Point(20, 198)
$installBox.AutoSize = $true
$form.Controls.Add($installBox)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 230)
$logBox.Size = New-Object System.Drawing.Size(700, 220)
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
    $installBox.Enabled = $enabled
    $urlBox.ReadOnly = -not $enabled
    $folderBox.ReadOnly = -not $enabled
}

function Start-Download {
    param(
        [ValidateSet("mp3", "mp4")]
        [string]$mode
    )

    if ($script:job) {
        Show-Error "Ya hay una descarga en curso."
        return
    }

    $url = $urlBox.Text.Trim()
    $folder = $folderBox.Text.Trim()

    [uri]$address = $null
    if (-not [uri]::TryCreate($url, [UriKind]::Absolute, [ref]$address) -or
        $address.Scheme -notin @("http", "https") -or -not $address.Host) {
        Show-Error "Pega un enlace completo que empiece por http:// o https://."
        return
    }

    if ([string]::IsNullOrWhiteSpace($folder)) {
        Show-Error "Elige una carpeta de salida."
        return
    }

    try {
        $folder = [IO.Directory]::CreateDirectory($folder).FullName
        $folderBox.Text = $folder
    } catch {
        Show-Error ("No se puede usar la carpeta seleccionada. " + $_.Exception.Message)
        return
    }

    $script:logFile = Join-Path $env:TEMP ("yt-dlp-gui-" + [guid]::NewGuid().ToString() + ".log")
    $script:lastContent = ""

    $modeText = $mode.ToUpper()

    $logBox.Clear()
    $logBox.AppendText("Modo: $modeText`r`n")
    $logBox.AppendText("Descargando en: $folder`r`n")
    $logBox.AppendText("URL: $url`r`n`r`n")
    $logBox.AppendText("Comprobando las herramientas de descarga...`r`n")

    Set-ButtonsEnabled $false

    $worker = {
        param($Url, $Folder, $LogFile, $Mode, $AllowInstall)

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

        $ytArgs += @("--", $Url)
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
    }

    try {
        $script:job = Start-Job -ScriptBlock $worker -ArgumentList $url, $folder, $script:logFile, $mode, $installBox.Checked -ErrorAction Stop
        $timer.Start()
    } catch {
        Set-ButtonsEnabled $true
        Show-Error ("No se pudo iniciar la descarga. " + $_.Exception.Message)
    }
}

$browseButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Elige dónde guardar el archivo"

    if ([IO.Directory]::Exists($folderBox.Text)) {
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

    if ([IO.Directory]::Exists($folder)) {
        Start-Process explorer.exe -ArgumentList "`"$folder`""
    } else {
        Show-Error "La carpeta no existe."
    }
})

$timer.Add_Tick({
    $finished = $script:job -and $script:job.State -in @("Completed", "Failed", "Stopped")
    if ($script:logFile -and (Test-Path $script:logFile)) {
        $content = Get-Content $script:logFile -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

        if ($content -ne $script:lastContent) {
            $script:lastContent = $content
            $logBox.Text = $content
            $logBox.SelectionStart = $logBox.Text.Length
            $logBox.ScrollToCaret()
        }
    }

    if ($finished) {
        $timer.Stop()

        Receive-Job $script:job -ErrorAction SilentlyContinue -ErrorVariable jobErrors | Out-Null
        if ($jobErrors -or $script:job.State -eq "Failed") {
            $reason = $script:job.ChildJobs[0].JobStateInfo.Reason
            $logBox.AppendText(("`r`nError de descarga: {0} {1}`r`n" -f $reason, ($jobErrors -join " ")))
        }
        Remove-Job $script:job -Force -ErrorAction SilentlyContinue

        $script:job = $null
        Remove-Item -LiteralPath $script:logFile -Force -ErrorAction SilentlyContinue
        $script:logFile = $null

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

$form.Add_FormClosed({
    $timer.Dispose()
    if ($script:logFile) {
        Remove-Item -LiteralPath $script:logFile -Force -ErrorAction SilentlyContinue
    }
})

$form.Add_Shown({
    $urlBox.Focus()
})

[void]$form.ShowDialog()
