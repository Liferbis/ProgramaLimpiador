# Limpiador de programas (v1.1.0)

Desinstalador y limpiador de residuos para Windows. Le das el **nombre de un programa** —aunque lo escribas con alguna errata— y se encarga de todo: lo busca, te deja elegir cuál de las coincidencias, lo desinstala y borra **todo su rastro** en `C:` (archivos, carpetas, accesos directos, registro, servicios, tareas e inicio).

Pensado para usarse sin escribir código: doble clic al `.bat`, escribes el nombre y confirmas.

## Archivos

| Archivo | Qué es |
|---|---|
| `Lanzador de limpieza.bat` | La interfaz. Menú con auto-elevación a administrador. Es lo que ejecutas. |
| `Limpiador.ps1` | El motor en PowerShell: búsqueda, desinstalación y barrido. El `.bat` lo llama solo. |
| `EstiloConsola.ps1` | Ajusta la fuente de la consola a Consolas para que se lea bien (acentos y símbolos). |
| `INSTRUCCIONES-IA.md` | El prompt del asistente de IA con el que se generó y evolucionó el proyecto. |

> Todos los archivos deben estar en la **misma carpeta**.

## Uso

1. Doble clic en `Lanzador de limpieza.bat` (se eleva a administrador solo).
2. Escribe el nombre del programa (la búsqueda tolera erratas y no distingue mayúsculas).
3. Elige en el listado cuál de las coincidencias quieres, o **Todas**.
4. Revisa la vista previa de lo que se desinstalaría y borraría.
5. Escribe `SI` para ejecutar. Hace una comprobación final para confirmar que no queda nada.

## Características

- **Búsqueda aproximada:** encuentra el programa aunque lo escribas mal (`clipgab` → `ClipGrab`), sin distinguir mayúsculas.
- **Selección:** si hay varias coincidencias, las lista y eliges una o todas.
- **Desinstalación oficial:** ejecuta el desinstalador registrado (silencioso si es MSI).
- **Barrido de residuos en `C:`:** rutas habituales a fondo y el resto del disco podando carpetas de sistema pesadas (`Windows`, `WinSxS`, etc.) para que sea rápido. No toca pendrives ni unidades externas.
- **Registro de lo borrado:** deja un `Limpieza_<nombre>_<fecha>.log` junto al script.

## Seguridad

- **Vista previa primero:** por defecto solo simula; nada se borra hasta que escribes `SI`.
- **Mínimo 3 caracteres** y coincidencia por **palabra completa** (no fragmentos sueltos).
- **Procesos blindados:** nunca toca procesos del sistema ni de aplicaciones críticas.
- **Exclusiones:** no toca lo que cruce el patrón protegido (`Windows`, `Microsoft Office`, `SQL Server`, `Common Files`).

## Uso avanzado (línea de comandos)

```powershell
.\Limpiador.ps1 -Nombre 'ClipGrab'                  # Simulación
.\Limpiador.ps1 -Nombre 'ClipGrab' -Programas 'ClipGrab 3.9.14' -Ejecutar
.\Limpiador.ps1 -Nombre 'ClipGrab' -Listar          # Lista coincidencias parecidas
.\Limpiador.ps1 -Nombre 'K-Lite|KLCodec' -Regex -Ejecutar
.\Limpiador.ps1 -Nombre 'ClipGrab' -Profundo        # Barrido también dentro de Windows
```

## Requisitos

- Windows 10/11. Se ejecuta como administrador (el `.bat` lo hace solo).

## Versiones y ramas

- **`v1.1.0` (rama `COMANDER`):** versión de consola — búsqueda aproximada, opción Salir, lista acotada y compatibilidad con PowerShell 5.1.
- **`v1.0.0`:** primera versión de consola.
- **Rama `Aplic`:** en desarrollo, una versión con interfaz gráfica (ventana con botones de radio para elegir el programa).

## Aviso

Borra archivos y claves de registro de forma permanente. Revisa siempre la vista previa antes de confirmar. Úsalo bajo tu responsabilidad.
