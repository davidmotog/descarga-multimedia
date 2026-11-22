using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Windows.Forms;

[assembly: AssemblyTitle("Descarga Multimedia")]
[assembly: AssemblyProduct("Descarga Multimedia")]
[assembly: AssemblyDescription("Descarga local de audio y vídeo")]
[assembly: AssemblyVersion(Programa.Version)]
[assembly: AssemblyFileVersion(Programa.Version)]
[assembly: AssemblyInformationalVersion(Programa.Version)]

internal static class Programa
{
    public const string Version = "2.2026.11.22";
    public static readonly string Datos = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DescargaMultimedia");
    static readonly Dictionary<string, Assembly> bibliotecas = new Dictionary<string, Assembly>();

    public static Stream Recurso(string nombre)
    {
        var stream = typeof(Programa).Assembly.GetManifestResourceStream(nombre);
        if (stream == null) throw new FileNotFoundException("Falta un recurso de la aplicación.", nombre);
        return stream;
    }

    public static string Texto(string nombre)
    {
        using (var lector = new StreamReader(Recurso(nombre))) return lector.ReadToEnd();
    }

    [STAThread]
    static void Main()
    {
        Application.EnableVisualStyles();
        ServicePointManager.SecurityProtocol |= SecurityProtocolType.Tls12;
        Application.SetCompatibleTextRenderingDefault(false);
        try
        {
            AppDomain.CurrentDomain.AssemblyResolve += Resolver;
            foreach (string nombre in new[] { "Microsoft.Web.WebView2.Core", "Microsoft.Web.WebView2.WinForms" })
            {
                using (var recurso = Recurso(nombre + ".dll"))
                using (var bytes = new MemoryStream())
                {
                    recurso.CopyTo(bytes);
                    bibliotecas[nombre] = Assembly.Load(bytes.ToArray());
                }
            }
            AbrirVentana();
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.GetBaseException().Message, "Descarga Multimedia", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }

    static Assembly Resolver(object sender, ResolveEventArgs args)
    {
        Assembly biblioteca;
        bibliotecas.TryGetValue(new AssemblyName(args.Name).Name, out biblioteca);
        return biblioteca;
    }

    [MethodImpl(MethodImplOptions.NoInlining)]
    static void AbrirVentana()
    {
        string arquitectura = !Environment.Is64BitProcess ? "x86" :
            (Environment.GetEnvironmentVariable("PROCESSOR_ARCHITECTURE") == "ARM64" ? "arm64" : "x64");
        string carpeta = Path.Combine(Datos, "SDK", typeof(Microsoft.Web.WebView2.Core.CoreWebView2Environment).Assembly.GetName().Version.ToString(), arquitectura);
        Directory.CreateDirectory(carpeta);
        string archivo = Path.Combine(carpeta, "WebView2Loader.dll");
        if (!File.Exists(archivo))
        {
            string temporal = archivo + "." + Guid.NewGuid().ToString("N");
            try
            {
                using (var salida = File.Create(temporal))
                using (var origen = Recurso("loader." + arquitectura)) origen.CopyTo(salida);
                try { File.Move(temporal, archivo); }
                catch (IOException) { if (!File.Exists(archivo)) throw; }
            }
            finally { File.Delete(temporal); }
        }
        Microsoft.Web.WebView2.Core.CoreWebView2Environment.SetLoaderDllFolderPath(carpeta);
        using (var ventana = new Ventana()) Application.Run(ventana);
    }
}
