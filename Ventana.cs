using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

internal sealed class Ventana : Form
{
    const string Publicaciones = "https://github.com/davidmotog/descarga-multimedia/releases";
    const string PaginaLocal = "https://descarga.example/index.html";
    readonly WebView2 web = new WebView2();
    readonly JavaScriptSerializer json = new JavaScriptSerializer();
    readonly Timer reloj = new Timer { Interval = 350 };
    readonly HttpClient http = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromSeconds(12) };
    string carpeta = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
    string log, resultado, archivo, formato, paginaVersion;
    long longitudLog;
    PowerShell trabajo;
    IAsyncResult ejecucion;
    bool comprobando, cerrando;

    public Ventana()
    {
        Text = "Descarga Multimedia";
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(900, 720);
        MinimumSize = new Size(580, 480);
        BackColor = Color.FromArgb(246, 246, 240);
        http.DefaultRequestHeaders.UserAgent.ParseAdd("DescargaMultimedia/" + Programa.Version);
        web.Dock = DockStyle.Fill;
        Controls.Add(web);
        Shown += async delegate { await IniciarVista(); };
        reloj.Tick += delegate { LeerDescarga(); };
    }

    async Task IniciarVista()
    {
        try
        {
            var entorno = await CoreWebView2Environment.CreateAsync(null, Path.Combine(Programa.Datos, "WebView2"));
            if (cerrando) return;
            await web.EnsureCoreWebView2Async(entorno);
            if (cerrando) return;
            var core = web.CoreWebView2;
            core.Settings.AreHostObjectsAllowed = false;
            core.Settings.AreDefaultContextMenusEnabled = false;
            core.Settings.IsStatusBarEnabled = false;
            core.AddWebResourceRequestedFilter(PaginaLocal, CoreWebView2WebResourceContext.Document);
            core.WebResourceRequested += (s, e) => {
                if (e.Request.Uri == PaginaLocal)
                    e.Response = entorno.CreateWebResourceResponse(Programa.Recurso("interfaz.html"), 200, "OK", "Content-Type: text/html; charset=utf-8");
            };
            core.NavigationStarting += (s, e) => { e.Cancel = e.Uri != PaginaLocal; };
            core.NewWindowRequested += (s, e) => { e.Handled = true; };
            core.WebMessageReceived += (s, e) => {
                if (cerrando || e.Source != PaginaLocal) return;
                string mensaje = e.WebMessageAsJson;
                BeginInvoke(new Action(() => Procesar(mensaje)));
            };
            core.Navigate(PaginaLocal);
        }
        catch (Exception ex)
        {
            if (cerrando) return;
            MessageBox.Show(this, "No se pudo iniciar la interfaz. Comprueba que Microsoft Edge WebView2 Runtime está instalado.\n\n" + ex.GetBaseException().Message, Text);
            Close();
        }
    }

    sealed class Solicitud
    {
        public string accion { get; set; }
        public string url { get; set; }
        public string modo { get; set; }
        public string carpeta { get; set; }
        public bool permitir { get; set; }
    }

    void Enviar(object mensaje)
    {
        if (!cerrando && web.CoreWebView2 != null) web.CoreWebView2.PostWebMessageAsJson(json.Serialize(mensaje));
    }

    async void Procesar(string mensaje)
    {
        if (cerrando) return;
        Solicitud peticion = null;
        try
        {
            peticion = json.Deserialize<Solicitud>(mensaje);
            switch (peticion.accion)
            {
                case "listo":
                    Enviar(new { tipo = "inicio", version = Programa.Version, carpeta });
                    break;
                case "carpeta":
                    if (trabajo != null) break;
                    using (var selector = new FolderBrowserDialog { SelectedPath = Directory.Exists(peticion.carpeta) ? peticion.carpeta : carpeta,
                        Description = "Elige dónde guardar el archivo" })
                    {
                        if (selector.ShowDialog(this) == DialogResult.OK)
                            Enviar(new { tipo = "carpeta", carpeta = selector.SelectedPath });
                    }
                    break;
                case "descargar":
                    if (trabajo == null) Descargar(peticion);
                    break;
                case "abrirCarpeta":
                    if (!Directory.Exists(peticion.carpeta)) throw new IOException("La carpeta seleccionada todavía no existe.");
                    Abrir(Path.GetFullPath(peticion.carpeta));
                    break;
                case "abrirArchivo":
                    if (archivo == null || !File.Exists(archivo)) throw new IOException("El archivo ya no está en la carpeta de descarga.");
                    Abrir(archivo);
                    break;
                case "actualizar":
                    await BuscarVersion();
                    break;
                case "verVersion":
                    if (paginaVersion != null) Abrir(paginaVersion);
                    break;
            }
        }
        catch (Exception ex)
        {
            Enviar(new { tipo = peticion != null && peticion.accion == "descargar" ? "fallo" : "aviso",
                texto = ex.GetBaseException().Message });
        }
    }

    static void Abrir(string destino)
    {
        Process.Start(new ProcessStartInfo(destino) { UseShellExecute = true });
    }

    async Task BuscarVersion()
    {
        if (comprobando) return;
        comprobando = true;
        paginaVersion = null;
        try
        {
            using (var respuesta = await http.GetAsync(Publicaciones + "/latest", HttpCompletionOption.ResponseHeadersRead))
            {
                var url = respuesta.Headers.Location;
                string prefijo = Publicaciones + "/tag/v";
                Version ultima;
                if ((int)respuesta.StatusCode / 100 != 3 || url == null || !url.IsAbsoluteUri ||
                    !url.AbsoluteUri.StartsWith(prefijo, StringComparison.Ordinal) ||
                    !Version.TryParse(url.AbsoluteUri.Substring(prefijo.Length), out ultima))
                    throw new InvalidDataException();
                if (ultima > new Version(Programa.Version)) paginaVersion = url.AbsoluteUri;
                Enviar(new { tipo = "actualizacion", disponible = paginaVersion != null,
                    texto = paginaVersion == null ? "Tienes la última versión." : "Descargar versión " + ultima });
            }
        }
        catch (Exception ex) { Enviar(new { tipo = "actualizacion", disponible = false, texto = "No se pudo consultar GitHub. " + ex.GetBaseException().Message }); }
        finally { comprobando = false; }
    }

    void Descargar(Solicitud peticion)
    {
        Uri enlace;
        if (!Uri.TryCreate(peticion.url, UriKind.Absolute, out enlace) ||
            (enlace.Scheme != "https" && enlace.Scheme != "http") || String.IsNullOrWhiteSpace(enlace.Host))
            throw new ArgumentException("Introduce un enlace HTTP o HTTPS válido.");
        if (peticion.modo != "mp3" && peticion.modo != "mp4") throw new ArgumentException("Selecciona MP3 o MP4.");
        if (String.IsNullOrWhiteSpace(peticion.carpeta)) throw new ArgumentException("Selecciona una carpeta de destino.");
        carpeta = Directory.CreateDirectory(peticion.carpeta).FullName;
        formato = peticion.modo;
        archivo = null;
        log = Path.Combine(Path.GetTempPath(), "descarga-" + Guid.NewGuid().ToString("N") + ".log");
        resultado = log + ".ruta";
        longitudLog = -1;
        try
        {
            trabajo = PowerShell.Create();
            trabajo.AddScript(Programa.Texto("Descargar.ps1")).AddParameter("Url", enlace.AbsoluteUri)
                .AddParameter("Folder", carpeta).AddParameter("LogFile", log).AddParameter("Mode", formato)
                .AddParameter("AllowInstall", peticion.permitir).AddParameter("ResultFile", resultado);
            ejecucion = trabajo.BeginInvoke();
            Enviar(new { tipo = "empezar", carpeta });
            reloj.Start();
        }
        catch { Limpiar(); throw; }
    }

    void LeerDescarga()
    {
        if (ejecucion == null) return;
        bool terminado = ejecucion.IsCompleted;
        string contenido = "";
        try
        {
            if (File.Exists(log))
            {
                using (var entrada = new FileStream(log, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                {
                    if (!terminado && entrada.Length == longitudLog) return;
                    longitudLog = entrada.Length;
                    if (entrada.Length > 48000) entrada.Seek(-48000, SeekOrigin.End);
                    using (var lector = new StreamReader(entrada, Encoding.UTF8)) contenido = lector.ReadToEnd();
                }
                Enviar(new { tipo = "registro", texto = contenido });
            }
            if (!terminado) return;
            trabajo.EndInvoke(ejecucion);
            if (contenido.Contains("FINALIZADO:") && File.Exists(resultado))
            {
                string ruta = Path.GetFullPath(File.ReadAllLines(resultado, Encoding.UTF8).Last().Trim());
                if (String.Equals(Path.GetDirectoryName(ruta), Path.GetDirectoryName(Path.Combine(carpeta, "archivo")), StringComparison.OrdinalIgnoreCase)
                    && String.Equals(Path.GetExtension(ruta), "." + formato, StringComparison.OrdinalIgnoreCase) && File.Exists(ruta))
                    archivo = ruta;
            }
            if (archivo == null)
            {
                string[] lineas = contenido.Split(new[] {'\r','\n'}, StringSplitOptions.RemoveEmptyEntries);
                string error = lineas.LastOrDefault(x => x.StartsWith("ERROR:") && !x.StartsWith("ERROR: yt-dlp terminó"))
                    ?? lineas.LastOrDefault(x => x.StartsWith("Falta ") || x.StartsWith("No se encuentra "))
                    ?? "Consulta el registro para ver qué ha ocurrido.";
                throw new IOException(error);
            }
            Enviar(new { tipo = "terminar", archivo = Path.GetFileName(archivo) });
        }
        catch (Exception ex)
        {
            if (!terminado) return;
            Enviar(new { tipo = "fallo", texto = ex.GetBaseException().Message });
        }
        finally { if (terminado) Limpiar(); }
    }

    void Limpiar()
    {
        reloj.Stop();
        if (trabajo != null) trabajo.Dispose();
        trabajo = null;
        ejecucion = null;
        foreach (string ruta in new[] { log, resultado })
            try { if (ruta != null) File.Delete(ruta); } catch (IOException) { }
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (trabajo != null && !ejecucion.IsCompleted &&
            MessageBox.Show(this, "Hay una descarga en curso. ¿Quieres cerrar la aplicación?", Text,
                MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
        { e.Cancel = true; return; }
        cerrando = true;
        if (trabajo != null) trabajo.Stop();
        Limpiar();
        reloj.Dispose();
        http.Dispose();
        base.OnFormClosing(e);
    }
}
