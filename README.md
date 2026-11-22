# Descarga Multimedia

Aplicación para Windows en español que guarda audio en MP3 o vídeo en MP4 a partir de un enlace. Utiliza yt-dlp para obtener el contenido y FFmpeg para convertirlo. Admite YouTube y otros sitios compatibles con yt-dlp. La disponibilidad depende del sitio y del contenido.

## Descargar y usar

1. Descarga **DescargaMultimedia.exe** desde [la última versión](https://github.com/davidmotog/descarga-multimedia/releases/latest).
2. Abre el programa, pega un enlace HTTP o HTTPS y elige **Audio · MP3** o **Vídeo · MP4**.
3. Elige la carpeta y pulsa **Descargar**. La ventana muestra el progreso y permite abrir el archivo terminado. Despliega **Registro técnico** para ver los detalles.

El nombre del archivo incluye el título y el identificador del contenido. Utiliza la aplicación con material propio o que tengas permiso para descargar.

La interfaz HTML se incluye en el ejecutable y se abre localmente con Microsoft Edge WebView2 Runtime. Si falta en tu equipo, puedes obtenerlo desde la [página de Microsoft](https://developer.microsoft.com/microsoft-edge/webview2/). La esquina superior derecha muestra la versión con el formato **2.año.mes.día**. Pulsa **Buscar actualización** para consultar la última publicación de GitHub.

## Herramientas de descarga

El programa busca yt-dlp y FFmpeg en Windows. Para los enlaces de YouTube también comprueba Deno. Si falta una herramienta, la ventana indica el comando para instalarla. Puedes marcar **Permitir que WinGet instale herramientas y actualice yt-dlp si hay un error 403** antes de iniciar la descarga para que la aplicación ejecute esa instalación. La casilla está desactivada al abrir el programa. Si la activas y el servidor devuelve un error HTTP 403, la aplicación comprueba si WinGet puede actualizar yt-dlp. Si cambia la versión activa, reintenta la misma descarga una vez.

Si cambia un sitio y las descargas empiezan a fallar, puedes actualizar yt-dlp con este comando cuando se haya instalado con WinGet.

```powershell
winget upgrade --id yt-dlp.yt-dlp --exact
```

Consulta la [lista de sitios de yt-dlp](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md) y la [guía de yt-dlp sobre Deno](https://github.com/yt-dlp/yt-dlp/wiki/EJS).

## Ejecutar desde el código fuente

Abre Windows PowerShell 5.1 en la carpeta del repositorio y ejecuta el script.

```powershell
.\DescargaMultimedia.ps1
```

El script compila el proyecto cuando hace falta. Para regenerar el ejecutable, usa Windows PowerShell 5.1 y .NET Framework 4.8. La compilación descarga el SDK WebView2 desde NuGet, comprueba su SHA-256 e incluye sus bibliotecas, la interfaz y el motor de descarga en el ejecutable.

```powershell
.\Compilar.ps1
```

Cada versión publicada incluye un archivo SHA256SUMS.txt. Puedes comparar su valor con el que devuelve este comando sobre tu copia del ejecutable.

```powershell
Get-FileHash .\DescargaMultimedia.exe -Algorithm SHA256
```
