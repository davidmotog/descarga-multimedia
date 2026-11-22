# Descarga Multimedia

Descarga audio en **MP3** o vídeo en **MP4** desde YouTube y otros sitios compatibles con yt-dlp. La aplicación está en español y se abre en Windows con una interfaz HTML local basada en WebView2.

**[Descargar DescargaMultimedia.exe](https://github.com/davidmotog/descarga-multimedia/releases/latest/download/DescargaMultimedia.exe)** · [Ver las notas de la última versión](https://github.com/davidmotog/descarga-multimedia/releases/latest)

![Ventana de Descarga Multimedia con el campo de enlace, el selector MP3 o MP4 y el botón Descargar](docs/interfaz.png)

Si Windows impide abrir el archivo, consulta [qué hacer si Windows 11 bloquea el ejecutable](#si-windows-11-bloquea-el-ejecutable).

## Requisitos

- **Windows** con Microsoft Edge WebView2 Runtime. Si la ventana indica que falta, instala [WebView2 Runtime desde Microsoft](https://developer.microsoft.com/microsoft-edge/webview2/).
- **yt-dlp y FFmpeg** para la descarga y la conversión. Para los enlaces de YouTube, la aplicación también comprueba **Deno**.
- **WinGet** si quieres que la aplicación instale las herramientas que falten. Activa la casilla correspondiente antes de descargar. Si la dejas desmarcada, el registro indica cómo instalar cada herramienta manualmente.

## Cómo se usa

1. Abre `DescargaMultimedia.exe` y pega el enlace HTTP o HTTPS del audio o vídeo.
2. Selecciona **Audio** para guardar un MP3 o **Vídeo** para guardar un MP4.
3. Revisa la ruta en **Guardar en**. Usa **Cambiar** para elegir otra carpeta.
4. Pulsa **Descargar**. La ventana muestra el progreso y, al finalizar, ofrece **Abrir archivo**. También puedes usar **Abrir carpeta** para ver lo descargado.

El nombre del archivo incluye el título y el identificador del contenido. La disponibilidad depende del sitio y del enlace. Usa la aplicación con contenido propio o que tengas permiso para descargar. [Consultar los sitios compatibles con yt-dlp](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)

## Actualizaciones y errores de descarga

- **Actualizar la aplicación.** La versión aparece arriba a la derecha con el formato `2.año.mes.día`. **Buscar actualización** consulta GitHub y ofrece un enlace si hay una versión posterior.
- **Resolver un error HTTP 403.** Si activas la casilla de WinGet y se produce ese error, la aplicación busca una actualización de yt-dlp. Cuando detecta que ha cambiado la versión activa, reintenta la descarga una vez.
- **Ver qué ha fallado.** Despliega **Registro técnico** y revisa el mensaje del sitio o de la herramienta. Para los problemas específicos de YouTube, consulta la [guía oficial de yt-dlp sobre Deno](https://github.com/yt-dlp/yt-dlp/wiki/EJS).

Si instalaste yt-dlp con WinGet, puedes actualizarlo también desde PowerShell.

```powershell
winget upgrade --id yt-dlp.yt-dlp --exact
```

## Si Windows 11 bloquea el ejecutable

La descarga de GitHub se distribuye sin firma digital. Si aparece **Control inteligente de aplicaciones**, Windows ha bloqueado el archivo antes de iniciar el programa. Este control se aplica a nivel de equipo y carece de excepciones para aplicaciones individuales. Puedes comprobar su estado en **Seguridad de Windows → Control de aplicaciones y navegador → Configuración de Control inteligente de aplicaciones**. [Preguntas frecuentes de Microsoft](https://support.microsoft.com/es-es/windows/security/threat-malware-protection/smart-app-control-frequently-asked-questions)

Si aparece **Windows protegió su PC** o **Editor desconocido** en un aviso de **Microsoft Defender SmartScreen**, se trata de la comprobación de reputación del archivo y del editor. [Cómo funciona SmartScreen](https://learn.microsoft.com/es-es/windows/apps/package-and-deploy/smartscreen-reputation)

Descarga el archivo desde los enlaces oficiales de este repositorio y [comprueba su SHA-256](#verificar-la-descarga). La suma comprueba la integridad del archivo. Para identificar al editor, Windows usa una firma de código de confianza. Si el aviso persiste, informa del mensaje exacto y de la versión de Windows. Si el equipo está administrado por una empresa, consulta con su equipo de TI. [Informar de un bloqueo en GitHub](https://github.com/davidmotog/descarga-multimedia/issues) · [Firma para Control inteligente de aplicaciones](https://learn.microsoft.com/es-es/windows/apps/develop/smart-app-control/code-signing-for-smart-app-control)

## Compilar desde el código fuente

Abre Windows PowerShell 5.1 en la carpeta del repositorio, en un equipo con .NET Framework 4.8. Ejecuta el siguiente comando para generar `DescargaMultimedia.exe`.

```powershell
.\Compilar.ps1
```

La compilación descarga el SDK de WebView2 desde NuGet, verifica su SHA-256 e incorpora al ejecutable las bibliotecas, la interfaz HTML y el motor de descarga. También puedes ejecutar `.\DescargaMultimedia.ps1` para abrir la aplicación y compilarla cuando haga falta.

## Verificar la descarga

Calcula el SHA-256 del ejecutable y compáralo con el valor de [SHA256SUMS.txt](https://github.com/davidmotog/descarga-multimedia/releases/latest/download/SHA256SUMS.txt) de la misma publicación.

```powershell
Get-FileHash .\DescargaMultimedia.exe -Algorithm SHA256
```

## Licencia

El código de este proyecto se distribuye con la [licencia MIT](LICENSE). Los componentes de terceros conservan sus respectivas licencias.
