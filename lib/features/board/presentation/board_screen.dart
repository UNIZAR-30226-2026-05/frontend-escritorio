import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/game_provider.dart';
import '../domain/gamemodels.dart';
import '../domain/websocket_service.dart';

// Clase de BoardScreen
// Se utiliza un ConsumerWidget porque se usa Riverpod. Este contiene un objeto
// ref dentro del método build
// Este objeto ref conecta la pantalla con el resto de controladores de la aplicación
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  // Inicialización de valores dummy para probar la app
  final String _gameId = "1";
  final String _playerId = "1"; // Ajustar si quieres ser otro jugador

  bool _showDebugOverlay = false; // Controlar si se muestran los números de las casillas

  // Coordenadas de los centros de las casillas en el tablero
  final Map<int, Offset> tileCenters = {
    0: const Offset(285, 900),
    1: const Offset(441, 952),
    2: const Offset(540, 952),
    3: const Offset(639, 952),
    4: const Offset(738, 952),
    5: const Offset(837, 952),
    6: const Offset(936, 952),
    7: const Offset(1035, 952),
    8: const Offset(1134, 952),
    9: const Offset(1233, 952),
    10: const Offset(1332, 952),
    11: const Offset(1431, 952),
    12: const Offset(1434, 945),
    13: const Offset(1539, 909),
    14: const Offset(1621, 852),
    15: const Offset(1695, 780),
    16: const Offset(1751, 691),
    17: const Offset(1788, 587),
    18: const Offset(1783, 488),
    19: const Offset(1767, 382),
    20: const Offset(1717, 283),
    21: const Offset(1638, 207),
    22: const Offset(1542, 155),
    23: const Offset(1431, 138),
    24: const Offset(1330, 138),
    25: const Offset(1230, 138),
    26: const Offset(1133, 137),
    27: const Offset(1035, 138),
    28: const Offset(937, 139),
    29: const Offset(836, 139),
    30: const Offset(738, 139),
    31: const Offset(636, 139),
    32: const Offset(539, 139),
    33: const Offset(440, 139),
    34: const Offset(342, 155),
    35: const Offset(337, 168),
    36: const Offset(255, 242),
    37: const Offset(203, 332),
    38: const Offset(181, 442),
    39: const Offset(192, 544),
    40: const Offset(239, 641),
    41: const Offset(337, 707),
    42: const Offset(441, 721),
    43: const Offset(539, 721),
    44: const Offset(640, 721),
    45: const Offset(738, 722),
    46: const Offset(836, 720),
    47: const Offset(935, 720),
    48: const Offset(1035, 721),
    49: const Offset(1131, 722),
    50: const Offset(1232, 722),
    51: const Offset(1331, 720),
    52: const Offset(1443, 694),
    53: const Offset(1519, 604),
    54: const Offset(1518, 489),
    55: const Offset(1439, 396),
    56: const Offset(1331, 369),
    57: const Offset(1233, 369),
    58: const Offset(1134, 369),
    59: const Offset(1035, 369),
    60: const Offset(936, 369),
    61: const Offset(837, 369),
    62: const Offset(736, 368),
    63: const Offset(637, 360),
    64: const Offset(527, 380),
    65: const Offset(449, 486),
    66: const Offset(532, 587),
    67: const Offset(638, 597),
    68: const Offset(737, 596),
    69: const Offset(835, 597),
    70: const Offset(935, 596),
    71: const Offset(1034, 595),
    72: const Offset(1307, 550),
  };

  @override
  void initState() {
    super.initState();
    // Conectamos el WebSocket tan pronto la pantalla se inicia
    // Usamos Future.microtask porque no podemos leer ref en initState directamente
    Future.microtask(() {
      ref.read(webSocketProvider).connect(_gameId, _playerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar el Estado Global
    // Esta función observa el gameProvider y cada vez que se emita un nuevo estado
    // (tirar un dado por ejemplo), se vuelve a dibujar la pantalla
    final gameState = ref.watch(gameProvider);
    final totalTiles = ref.read(gameProvider.notifier).totalTiles;

    // Obtener el jugador activo usando el ID del turnOrder
    final activePlayerId = gameState.turnOrder[gameState.activePlayerIndex];
    final currentPlayer =
        gameState.players.firstWhere((p) => p.id == activePlayerId);

    return Scaffold(
      appBar: AppBar(title: const Text('Snow Party - Tablero Base')),
      body: Column(
        children: [
          // HUD (Panel superior)
          // Muestra de quién es el turno con el color de su personaje
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            width: double.infinity,
            child: Column(
              children: [
                Text(gameState.serverMessage,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // TODO Añadir la UI de la economía (RF09) y la tienda (RF10).
                // Leer currentPlayer.coins y mostrar un icono de moneda,
                // y un botón flotante para abrir el inventario (currentPlayer.itemInventory).
                Text('Turno de: ${currentPlayer.username}',
                    style: TextStyle(
                        fontSize: 16,
                        color:
                            getCharacterColor(currentPlayer.characterClass))),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Ver índices de casillas: ",
                        style: TextStyle(fontSize: 12)),
                    Switch(
                      value: _showDebugOverlay,
                      activeColor: Colors.red,
                      onChanged: (val) =>
                          setState(() => _showDebugOverlay = val),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tablero
          // Con GridView se crea una cuadrícula de 5 columnas y se dibujan las casillas.
          Expanded(
            child: InteractiveViewer(
              minScale: 0.1,
              maxScale: 4.0,
              constrained:
                  false, // Permite que la imagen sea más grande que la pantalla y hacer paneo
              child: Stack(
                children: [
                  // Imagen del tablero
                  Image.asset(
                    'assets/images/board/tablero_def.png',
                    fit: BoxFit.none,
                  ),

                  // Capa de los jugadores
                  ...List.generate(totalTiles, (index) {
                    // Filtrar qué jugadores están en exactamente esta casilla con índice 'index'
                    final playersHere = gameState.players
                        .where((p) => p.currentTileIndex == index)
                        .toList();

                    if (playersHere.isEmpty) return const SizedBox.shrink();

                    // TODO: Reemplazar con las coordenadas reales (x, y) de cada casilla en `tablero_def.png`
                    // Posicionamiento temporal (en forma de grid) para que se vean sobre la imagen
                    final tileCenter = tileCenters[index] ?? Offset.zero;

                    return Positioned(
                      left: tileCenter.dx - 20, // Centrar horizontalmente (mitad del ancho 40)
                      top: tileCenter.dy - 10,  // Centrar verticalmente (mitad del alto ~20)
                      child: Container(
                        width:
                            40, // Ancho estimado de la zona para centrar figuritas
                        alignment: Alignment.center,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 4,
                          runSpacing: 4,
                          children: playersHere
                              .map((p) => CircleAvatar(
                                    backgroundColor:
                                        getCharacterColor(p.characterClass),
                                    radius: 10,
                                  ))
                              .toList(),
                        ),
                      ),
                    );
                  }),

                  // Capa de Debug (Círculos con índice)
                  if (_showDebugOverlay)
                    ...tileCenters.entries.map((entry) {
                      return Positioned(
                        left: entry.value.dx - 20,
                        top: entry.value.dy - 10,
                        child: IgnorePointer(
                          child: Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Text(
                                '${entry.key}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // Controles (Tirar Dado)
          Padding(
            padding: const EdgeInsets.all(32.0),
            // Botón de tirar el dato con el color del personaje
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                backgroundColor:
                    getCharacterColor(currentPlayer.characterClass),
              ),
              // Función que se activa al presionar y tira el dado (función rollDice())
              // Cuando se presiona se verifica si la partida ha acabado
              onPressed: gameState.currentPhase == GamePhase.finished
                  ? null // Si el juego se ha acabado, el botón se deshabilita
                  // Lógica local para probar sin backend:
                  : () => ref.read(gameProvider.notifier).rollDice(),
                  // Cuando el backend esté listo, descomentar la siguiente línea y comentar la anterior:
                  // : () => ref.read(webSocketProvider).rollDiceCommand(_gameId, currentPlayer.id),
              // Imprime el resultado de tirar el dado con lastDiceResult
              child: Text(
                gameState.lastDiceResult == null
                    ? 'Tirar Dado'
                    : 'Sacaste un ${gameState.lastDiceResult} - Tirar de nuevo',
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// Función para devolver un color dado un personaje
// TODO Cambiarlo para que devuelva una imagen en vez de un color
Color getCharacterColor(CharacterClass charClass) {
  switch (charClass) {
    case CharacterClass.banquero:
      return Colors.green; // El Banquero es verde
    case CharacterClass.vidente:
      return Colors.purple; // El Místico es morado
    case CharacterClass.escapista:
      return Colors.black; // El Escapista es negro
    case CharacterClass.videojugador:
      return Colors.orange; // El Gamer es naranja
  }
}
