# Parkour de Velocidad (Roblox)

Juego de parkour contrarreloj: corre, desliza y salta por las paredes para conseguir el mejor tiempo y subir al ranking global.

## Qué incluye

- **Movimiento de parkour**
  - Momentum: cuanto más tiempo corres sin parar, más rápido vas (16 → 34)
  - Deslizamiento (`C` / `Ctrl`): da un empujón de velocidad
  - Wall run: salta hacia una pared mientras corres y avanzas por ella
  - Wall jump: pulsa `Espacio` mientras corres por la pared
  - La cámara se abre (FOV) con la velocidad y se inclina en el wall run
- **Sensaciones**
  - Cuenta atrás 3-2-1-¡YA! en la salida (te quedas quieto en la línea)
  - Poses: el cuerpo se inclina al deslizar y al correr por la pared
  - Rastro de colores a alta velocidad y polvo al deslizar
  - Sonidos: cuenta atrás, checkpoints, récord, deslizar, wall jump, aterrizaje y viento según la velocidad
  - Temblor de cámara al caer desde muy alto y confeti al batir tu récord
- **Carrera**: salida, checkpoints en orden, meta y cronómetro medido por el servidor (anti-trampas básico)
- **Caídas**: si caes, vuelves al último checkpoint sin parar el tiempo
- **Récords**: mejor tiempo guardado (DataStore), en la tabla de jugadores y en un ranking Top 10
- **HUD**: cronómetro, checkpoints, mejor tiempo y mensajes de récord
- **Mapa de prueba generado automáticamente**: saltos, doble wall run, rampa de velocidad y escalera final
- Botones táctiles para móvil (Deslizar / Reiniciar)

## Controles

| Acción | Teclado | Mando |
|---|---|---|
| Deslizar | `C` o `Ctrl` | B |
| Wall jump | `Espacio` (en la pared) | A |
| Reiniciar | `R` | Y |

## Cómo meterlo en Roblox Studio

### Opción rápida: abrir el archivo del juego
1. Descarga `ParkourVelocidad.rbxlx` de este repositorio (botón **Download raw file** en GitHub).
2. Haz doble clic en el archivo, o en Studio usa **File > Open from File**.
3. Pulsa **Play**. El mapa aparece al empezar la partida (en modo edición no se ve, porque lo crea un script).

Para regenerar el archivo después de cambiar el código: `rojo build -o ParkourVelocidad.rbxlx`.

### Opción A: con Rojo (recomendado)
1. Instala [Rojo](https://rojo.space) y su plugin de Studio.
2. En esta carpeta ejecuta `rojo serve`.
3. En Studio, abre un Baseplate, pulsa **Connect** en el plugin de Rojo y dale a Play.

### Opción B: a mano (copiar y pegar)
Crea estos objetos en Studio y pega el código de cada archivo:

| Archivo | Dónde va en Studio | Tipo |
|---|---|---|
| `src/shared/Config.luau` | `ReplicatedStorage > Shared > Config` | ModuleScript |
| `src/server/CourseBuilder.luau` | `ServerScriptService > Server > CourseBuilder` | ModuleScript |
| `src/server/Leaderboard.luau` | `ServerScriptService > Server > Leaderboard` | ModuleScript |
| `src/server/RaceService.server.luau` | `ServerScriptService > Server > RaceService` | Script |
| `src/client/RaceHUD.client.luau` | `StarterPlayer > StarterPlayerScripts > RaceHUD` | LocalScript |
| `src/character/Movement.client.luau` | `StarterPlayer > StarterCharacterScripts > Movement` | LocalScript |

`Shared` y `Server` son carpetas (Folder).

### Guardar récords
En Studio: **Home > Game Settings > Security > Enable Studio Access to API Services**. Sin esto el juego funciona igual, pero los récords solo duran la sesión.

## Sonidos

Los sonidos usan archivos que vienen con Roblox. Si alguno no suena, o quieres otros, busca sonidos en la **Creator Store** (Toolbox > Audio), copia su ID y ponlo en `Sounds` dentro de `Config.luau` así: `"rbxassetid://123456789"`.

## Hacer tu propio mapa

Si en `Workspace` existe una carpeta llamada `Course`, el juego la usa en lugar de generar el mapa de prueba. Tiene que tener:

```
Course
├── Spawn          (SpawnLocation)
├── Start          (Part, CanCollide desactivado, con la cara frontal mirando al circuito: inicia la cuenta atrás)
├── Finish         (Part, CanCollide desactivado: para el tiempo)
├── Checkpoints    (Folder)
│   ├── 1          (Part con el atributo Index = 1)
│   ├── 2          (Part con el atributo Index = 2)
│   └── ...
├── KillParts      (Folder opcional: Parts que te devuelven al checkpoint)
└── Leaderboard    (Part opcional: muestra el ranking en su cara frontal)
```

Ajusta `FallY` en `Config.luau` para que esté por debajo de tu mapa.

## Ajustar el juego

Todo lo importante está en `src/shared/Config.luau`: velocidades, fuerza de salto, duración del wall run, cámara, etc.

## Próximas ideas

- Más mapas y un selector de mapas
- Modo fantasma (correr contra tu mejor intento)
- Monedas y tienda de trails
- Medallas por tiempo (oro / plata / bronce)
