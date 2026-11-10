# Limpiador

Desinstalador y limpiador de residuos para Windows. Le das el **nombre de un programa** y se encarga de todo: comprueba si está instalado, lo desinstala y borra **todo su rastro** en `C:` (archivos, carpetas, accesos directos, registro, servicios, tareas e inicio).

Pensado para usarse sin escribir una línea de código: doble clic al `.bat`, escribes el nombre y confirmas.

## Archivos

| Archivo | Qué es |
|---|---|
| `Lanzador de limpieza.bat` | La interfaz. Menú con auto-elevación a administrador. Es lo que ejecutas. |
| `Limpiador.ps1` | El motor en PowerShell. Hace la desinstalación y el barrido. El `.bat` lo llama solo. |
| `INSTRUCCIONES-IA.md` | El prompt del asistente de IA con el que se generó y fue evolucionando el proyecto. |

> Los dos archivos (`.bat` y `.ps1`) tienen que estar en la **misma carpeta**.

## Uso

1. Doble clic en `Lanzador de limpieza.bat` (se eleva a administrador solo).
2. Escribe el nombre del programa a eliminar.
3. Revisa la vista previa de lo que se desinstalaría y borraría.
4. Escribe `SI` para ejecutar. Hace una comprobación final para confirmar que no queda nada.

Si el nombre no corresponde a nada instalado ni con residuos, avisa y no escanea de más.

## Qué hace por dentro

- **Desinstalación oficial:** ejecuta el desinstalador registrado del programa (silencioso si es MSI).
- **Barrido de residuos en C::** rutas habituales (Program Files, AppData, ProgramData, Descargas, Escritorio, Documentos, menú Inicio) a fondo, y el resto de `C:` podando carpetas de sistema pesadas (`Windows`, `WinSxS`, `$Recycle.Bin`, etc.) para que sea rápido.
- **Registro:** claves de software, clases, asociaciones y entradas de desinstalación huérfanas.
- **Servicios, tareas programadas e inicio:** los detecta y avisa (no los borra en bloque, por seguridad).

## Seguridad

- **Vista previa primero:** por defecto solo simula; nada se borra hasta que escribes `SI`.
- **Exclusiones:** nunca toca lo que cruce el patrón protegido (por defecto `Windows`, `Microsoft Office`, `SQL Server`, `Common Files`). Ampliable si el nombre es genérico.
- **Solo C::** pendrives y unidades externas quedan fuera; ni se miran.
- **Comprobación final** tras limpiar para verificar que no queda rastro.

## Parámetros del script (uso avanzado)

\`\`\`powershell
.\Limpiador.ps1 -Nombre 'ClipGrab'                 # Simulación (no borra)
.\Limpiador.ps1 -Nombre 'ClipGrab' -Ejecutar       # Desinstala y borra
.\Limpiador.ps1 -Nombre 'K-Lite|KLCodec' -Ejecutar # El nombre admite regex
.\Limpiador.ps1 -Nombre 'ClipGrab' -Excluir 'Windows|Office|MiApp'  # Blindar nombres
.\Limpiador.ps1 -Nombre 'ClipGrab' -Profundo       # Barrido paranoico (incluye Windows, más hondo)
\`\`\`

## Requisitos

- Windows 10/11.
- Ejecutar como administrador (el `.bat` lo hace solo).

## Aviso

Esta herramienta borra archivos y claves de registro de forma permanente. Revisa siempre la vista previa antes de confirmar. Úsala bajo tu responsabilidad.
