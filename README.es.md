# GestionePuntiRipristino

Herramienta gráfica para Windows 11 para crear, ver, modificar y eliminar puntos de restauración del sistema.

## Requisitos

- **Windows 11** (también funciona en Windows 10)
- **PowerShell 5.1+**
- **Ejecutar como Administrador** (necesario para interactuar con Volume Shadow Copy)

## Instalación

Descarga `GestionePuntiRipristino.ps1` y ejecútalo como Administrador:

```powershell
.\GestionePuntiRipristino.ps1
```

O desde Explorer: clic derecho → **Ejecutar con PowerShell**.

## Funcionalidades

- **Listar puntos** — muestra todos los puntos existentes con fecha y descripción
- **Eliminar** — elimina un punto específico con confirmación
- **Crear** — crea un nuevo punto de restauración
- **Editar descripción** — personaliza las descripciones (guardadas en HKCU\Software\OttimizzaWindows)
- **Iniciar Restauración** — abre la interfaz nativa de Windows (`rstrui.exe`)

## Seguridad

- Validación UUID estricta antes de cada operación con `vssadmin`
- Procesos ejecutados con `Process.Start` sin shell intermedios
- Timeout de 30 segundos para evitar bloqueos
- Auditoría en Windows Event Log (origen: `OttimizzaWindows`)
- Descripciones almacenadas en el Registro (HKCU), no en archivos temporales

## Licencia

MIT
