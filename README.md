# Parkour de Velocidad (Roblox)

Juego de parkour contrarreloj: corre, desliza y salta por las paredes para conseguir el mejor tiempo, ganar medallas y subir en el ranking.

## Qué incluye

**Movimiento**
- Momentum: cuanto más corres sin parar, más rápido vas
- Deslizamiento (`C` / `Ctrl` / botón en móvil), wall run y wall jump
- Poses al deslizar y en la pared, cámara que reacciona a la velocidad

**Contenido**
- Lobby decorado: plaza con anillos holográficos, farolas, árboles, bancos, ciudad de neón de fondo
- Portales a cada mapa y una pared de rankings detrás del spawn
- 5 mapas, cada uno más largo y difícil que el anterior: Tutorial y Ciudad (gratis), Neón (150 monedas), Selva (400 monedas) y Cielo (solo VIP, el más largo y difícil)
- Obstáculos: plataformas móviles, trampolines, tirolinas y zonas de gravedad baja
- Medallas por mapa: bronce, plata, oro y desarrollador

**Competición**
- Modo fantasma: una silueta repite tu mejor intento mientras corres
- Parciales en verde o rojo en cada checkpoint respecto a tu récord
- Ranking histórico y semanal por mapa
- Carreras en vivo: los jugadores en cola corren a la vez en un mapa al azar

**Progreso**
- Monedas y XP por terminar mapas, medallas nuevas, récords y carreras en vivo
- Niveles con barra de XP
- Tienda de cosméticos: rastros, efectos de salto y de deslizamiento
- Pase VIP: mapa Cielo, objetos exclusivos y +50% de monedas
- Pases de monedas x2, x3, x5 y x10 que se desbloquean en orden
- Puesto de tienda en el lobby que abre los pases de Robux

**Calidad**
- Menú de inicio, mapa tutorial con carteles y menú de ajustes
- Interfaz que se adapta a pantallas pequeñas y botones grandes en móvil
- Datos guardados en DataStore: récords, medallas, monedas, compras y ajustes

## Controles

| Acción | Teclado | Mando | Móvil |
|---|---|---|---|
| Deslizar | `C` o `Ctrl` | B | Botón "Deslizar" |
| Wall jump / soltar tirolina | `Espacio` | A | Botón de salto |
| Reiniciar | `R` | Y | Botón "Reiniciar" |

## Cómo abrirlo en Roblox Studio

### Opción rápida: abrir el archivo del juego
1. Descarga `ParkourVelocidad.rbxlx` de este repositorio (botón **Download raw file** en GitHub).
2. Haz doble clic en el archivo, o en Studio usa **File > Open from File**.
3. Pulsa **Play**. El lobby y los mapas aparecen al empezar la partida (en modo edición no se ven, porque los crea un script).

### Opción con Rojo
1. Instala [Rojo](https://rojo.space) y su plugin de Studio.
2. En esta carpeta ejecuta `rojo serve`, o `rojo build -o ParkourVelocidad.rbxlx` para regenerar el archivo.
3. En Studio pulsa **Connect** en el plugin de Rojo y dale a Play.

Si copias los scripts a mano en otro proyecto, desactiva **Workspace > StreamingEnabled**: el juego necesita que los mapas estén cargados en el cliente.

## Configurar antes de publicar

1. **Guardar datos**: en Studio, **Home > Game Settings > Security > Enable Studio Access to API Services**. Sin esto el juego funciona, pero nada se guarda entre sesiones.
2. **Game Pass**: crea los pases en el [Creator Hub](https://create.roblox.com) (tu juego > Monetization > Passes) y pon sus IDs en `src/shared/Config.luau`: el VIP en `VipGamePassId` y los de monedas en `CoinPasses` (x2, x3, x5 y x10). Los pases sin ID salen como "Próximamente".
3. **Medallas**: los tiempos de medalla se calculan solos según la longitud de cada mapa. Si quieres fijarlos a mano, añade `Bronze`, `Silver`, `Gold` y `Dev` en los atributos del mapa en `src/server/CourseBuilder.luau`. Lo normal es poner como medalla de desarrollador tu mejor tiempo.
4. **Precio y recompensa de los niveles**: atributos `Price` (monedas para desbloquearlo, 0 = gratis) y `Reward` (multiplicador de monedas: Ciudad x1, Neón x1,5, Selva x2 y Cielo x3) de cada mapa en `CourseBuilder.luau`.
5. **Carreras en vivo**: necesitan 2 jugadores. Para probar solo en Studio, pon `LiveRace.MinPlayers = 1` en `Config.luau`.
6. **Sonidos**: usan archivos que vienen con Roblox. Si alguno no suena, busca otro en la Creator Store (Toolbox > Audio) y pon su ID en `Sounds` dentro de `Config.luau` así: `"rbxassetid://123456789"`.

## Estructura del código

```
src/shared/      (ReplicatedStorage.Shared)
  Config         ajustes del juego: velocidades, recompensas, medallas...
  Catalog        objetos de la tienda
  Remotes        todos los RemoteEvents/RemoteFunctions
  Sfx            sonidos
src/server/      (ServerScriptService.Server)
  Main           arranque del servidor
  CourseBuilder  genera el lobby y los mapas
  LobbyDecor     decoración del lobby e iluminación
  BuildUtil      funciones para crear piezas, carteles y partículas
  Maps           registro de mapas
  RaceService    carreras: cuenta atrás, checkpoints, meta, caídas
  PlayerData     datos guardados del jugador
  Leaderboard    rankings por mapa (histórico y semanal)
  Ghosts         guarda el fantasma de cada récord
  LiveRace       carreras en vivo
  Economy        monedas, XP y niveles
  Shop           tienda de cosméticos y rastros
  Passes         Game Pass: VIP y multiplicadores de monedas
  MapUnlocks     niveles que se desbloquean con monedas
src/client/      (StarterPlayerScripts.Client)
  Main           arranque del cliente
  HUD, MapMenu, ShopMenu, SettingsMenu, StartMenu, LiveRaceUI   interfaz
  Obstacles      plataformas móviles, trampolines, tirolinas, gravedad baja
  Ghost          graba y reproduce el fantasma
  ClientState    datos del jugador en el cliente
src/character/   (StarterCharacterScripts.Character)
  Movement       movimiento de parkour
  Effects        poses, partículas, sonidos y cámara
```

## Añadir un mapa

La forma más fácil es añadir una entrada a `CourseBuilder.Definitions` en `src/server/CourseBuilder.luau`, copiando uno de los mapas que ya hay. Las piezas disponibles son:

| Función | Qué crea |
|---|---|
| `m:start()` | plataforma de salida y línea de salida |
| `m:block(largo, ancho, altura, x)` | plataforma |
| `m:runway(largo, altura)` | pista para coger velocidad |
| `m:gap(distancia)` | hueco |
| `m:checkpoint(plataforma)` | checkpoint sobre una plataforma |
| `m:wallRun(lado, largo, altura)` | hueco con pared para wall run (lado -1 izquierda, 1 derecha) |
| `m:ramp(largo, subida, altura)` | rampa |
| `m:trampoline(altura, x)` | trampolín |
| `m:moving(largo, ancho, altura, desplazamiento, periodo, fase)` | plataforma móvil |
| `m:zipline(largo, bajada, altura)` | tirolina |
| `m:lowGravity(largo, altura)` | zona de gravedad baja |
| `m:zigzag(cantidad, hueco, tamaño, separación, altura, subida)` | plataformas alternando izquierda/derecha |
| `m:stairs(cantidad, hueco, tamaño, altura, subida)` | escalera de plataformas |
| `m:beam(largo, ancho, altura)` | viga estrecha para hacer equilibrio |
| `m:sign(texto, altura)` | cartel flotante |
| `m:finish(altura)` | meta |

También puedes construir los mapas a mano en Studio. Si existe `Workspace/Maps`, el juego usa esos mapas (y `Workspace/Lobby`) en lugar de generarlos. Cada mapa es una carpeta con:

```
Maps/<id>                (Folder con atributos DisplayName, Order, Color,
                          Bronze, Silver, Gold, Dev y, opcionalmente, Vip o Tutorial)
├── StartPad             (Part donde apareces)
├── Start                (Part sin colisión, con la cara frontal mirando al circuito)
├── Finish               (Part sin colisión)
└── Checkpoints          (Folder con Parts que tienen el atributo Index = 1, 2, 3...)

Lobby
├── Spawn                (SpawnLocation)
├── Portals              (Parts con el atributo MapId)
├── Boards               (Parts con el atributo MapId para el ranking)
└── LiveRacePad          (Part para unirse a la carrera en vivo)
```

Los obstáculos especiales se marcan con etiquetas (Tags): `MovingPlatform` (atributos Offset, Period, Phase), `Trampoline` (Power), `Zipline` (A y B: puntos del cable) y `LowGravity` (Gravity).
