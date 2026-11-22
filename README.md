# Descarga Multimedia

Aplicación para Windows en español que guarda audio en MP3 o vídeo en MP4 a partir de un enlace. Utiliza yt-dlp para obtener el contenido y FFmpeg para convertirlo. Admite YouTube y otros sitios compatibles con yt-dlp. La disponibilidad depende del sitio y del contenido.

## Descargar y usar

1. Descarga **DescargaMultimedia.exe** desde [la última versión](https://github.com/davidmotog/descarga-multimedia/releases/latest).
2. Abre el programa, pega un enlace HTTP o HTTPS y elige una carpeta.
3. Pulsa **Descargar MP3** para guardar el audio o **Descargar MP4** para guardar el vídeo. El registro muestra el resultado y el botón **Abrir carpeta** te lleva a los archivos.

El nombre del archivo incluye el título y el identificador del contenido. Utiliza la aplicación con material propio o que tengas permiso para descargar.

## Herramientas de descarga

El programa busca yt-dlp y FFmpeg en Windows. Para los enlaces de YouTube también comprueba Deno. Si falta una herramienta, la ventana indica el comando para instalarla. Puedes marcar **Permitir que WinGet instale las herramientas que falten** antes de iniciar la descarga para que la aplicación ejecute esa instalación. La casilla está desactivada al abrir el programa.

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

Para generar el ejecutable en esa misma carpeta, utiliza PS2EXE.

```powershell
Install-Module ps2exe -RequiredVersion 1.0.17 -Scope CurrentUser
.\Compilar.ps1
```

Cada versión publicada incluye un archivo SHA256SUMS.txt. Puedes comparar su valor con el que devuelve este comando sobre tu copia del ejecutable.

```powershell
Get-FileHash .\DescargaMultimedia.exe -Algorithm SHA256
```
