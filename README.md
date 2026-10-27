# UCReconocimiento

App de pruebas en Flutter (Android/iOS) que usa la cámara para **identificar los puertos de entrada y salida de una unidad de control** y superponerlos en realidad aumentada. Sirve de base para construir el manual de instalación.

Primer equipo soportado: **Koolnova Radio Central Unit HYBRID** (cód. `100-CPNH00`).

## Qué hace

| Pantalla | Descripción |
|---|---|
| Identificar puertos | Cámara en vivo. Lee las etiquetas impresas (`ZONE 1`, `COM D- D+`, `GND B- A+ +24`…) y dibuja sobre la imagen el conector y sus bornes. Toca un puerto para ver su función. |
| Instalación guiada | Mismo visor con un panel paso a paso. Resalta el puerto (y el borne) objetivo y avisa si hay que girar la unidad. |
| Analizar foto | Ejecuta el mismo reconocimiento sobre una foto y muestra el texto OCR en bruto, útil para ajustar patrones. |
| Catálogo de puertos | Lista de puertos por lateral con descripción y estado de validación. |
| Borrador del manual | Genera el manual de instalación en Markdown a partir de la definición del equipo. |

## Cómo funciona

```
Cámara ──► ML Kit Text Recognition (on-device, sin internet)
             │ líneas y palabras con sus 4 esquinas
             ▼
        PortMatcher ── patrones regex por puerto (assets/devices/*.json)
             │ etiqueta encontrada → se proyecta el conector "debajo"
             │ del texto (respeta la rotación) y se ubica cada borne
             ▼
        DetectionTracker (suavizado y persistencia entre fotogramas)
             ▼
        PortOverlay (CustomPainter sobre CameraPreview)
```

Las etiquetas de esta central están serigrafiadas junto a cada conector, así que no hace falta entrenar un modelo de visión: el texto actúa como ancla. El código del reconocimiento (`lib/vision/port_matcher.dart`) no depende de ML Kit y está cubierto por tests.

## Estructura

```
assets/devices/koolnova_rcu_hybrid.json  Puertos, patrones OCR, laterales y pasos de instalación
lib/models/            Modelo de datos del equipo
lib/vision/            OCR → puertos (quad.dart, port_matcher.dart, detection_tracker.dart, mlkit_adapter.dart)
lib/ui/screens/        Pantallas
lib/ui/widgets/        Overlay AR, panel de pasos, ficha de puerto
lib/manual/            Generador del borrador del manual
test/                  Tests del reconocimiento, la definición y la UI
```

## Ejecutar

Requisitos: Flutter 3.47+, dispositivo físico Android (minSdk 24) o iOS 15.5+. ML Kit no funciona en emuladores sin cámara ni en web/escritorio.

```bash
flutter pub get
flutter test
flutter run            # con el móvil conectado
```

Consejos de uso: buena luz (hay botón de linterna), enfoca un lateral cada vez con las etiquetas lo más horizontales posible y usa el zoom si el texto es pequeño.

## Añadir o ajustar un equipo

1. Copia `assets/devices/koolnova_rcu_hybrid.json` y edítalo:
   - `ports[].patterns`: expresiones regulares (sobre texto en mayúsculas) que reconocen la etiqueta. Incluye confusiones típicas del OCR (`[O0]`, `[1IL|]`, `[5S]`…).
   - `ports[].pins`: bornes en el orden en que están impresos.
   - `ports[].connector`: `gap` y `depth` (en alturas de etiqueta) para ubicar el conector respecto al texto.
   - `steps`: procedimiento de instalación; `port`/`pin` indican qué resaltar.
2. Añade la ruta a `DeviceRepository.deviceAssets`.
3. Usa **Analizar foto** para comprobar qué lee el OCR y afinar los patrones.

## Pendiente de validar

Las funciones de los puertos se dedujeron de la serigrafía (`verified: false`). Antes de publicar el manual hay que confirmarlas con el manual oficial de Koolnova, en especial `H ALR`, `AUX 1`, `AUX 2`, el conector gris `BUS`, el jumper junto a `COM D- D+` y el número de bornes de cada `ZONE`.
