import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/game_provider.dart';
import '../domain/gamemodels.dart';
import '../data/websocket_service.dart';
import '../../auth/presentation/controllers/auth_provider.dart';
import '../../lobby/presentation/controllers/lobby_provider.dart';
import 'widgets/inventory_panel.dart';
import '../../shop/presentation/controllers/shop_providers.dart';
import 'widgets/minigame_overlay.dart';

// ============================================================
// BoardScreen — Pantalla principal del tablero de juego
// Layout fijo con tablero centrado y paneles UI superpuestos
// ============================================================
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  bool _isShopOpen = false;

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
    12: const Offset(1539, 909),
    13: const Offset(1621, 852),
    14: const Offset(1695, 780),
    15: const Offset(1751, 691),
    16: const Offset(1788, 587),
    17: const Offset(1783, 488),
    18: const Offset(1767, 382),
    19: const Offset(1717, 283),
    20: const Offset(1638, 207),
    21: const Offset(1542, 155),
    22: const Offset(1431, 138),
    23: const Offset(1330, 138),
    24: const Offset(1230, 138),
    25: const Offset(1133, 137),
    26: const Offset(1035, 138),
    27: const Offset(937, 139),
    28: const Offset(836, 139),
    29: const Offset(738, 139),
    30: const Offset(636, 139),
    31: const Offset(539, 139),
    32: const Offset(440, 139),
    33: const Offset(342, 155),
    34: const Offset(255, 242),
    35: const Offset(203, 332),
    36: const Offset(181, 442),
    37: const Offset(192, 544),
    38: const Offset(239, 641),
    39: const Offset(337, 707),
    40: const Offset(441, 721),
    41: const Offset(539, 721),
    42: const Offset(640, 721),
    43: const Offset(738, 722),
    44: const Offset(836, 720),
    45: const Offset(935, 720),
    46: const Offset(1035, 721),
    47: const Offset(1131, 722),
    48: const Offset(1232, 722),
    49: const Offset(1331, 720),
    50: const Offset(1443, 694),
    51: const Offset(1519, 604),
    52: const Offset(1518, 489),
    53: const Offset(1439, 396),
    54: const Offset(1331, 369),
    55: const Offset(1233, 369),
    56: const Offset(1134, 369),
    57: const Offset(1035, 369),
    58: const Offset(936, 369),
    59: const Offset(837, 369),
    60: const Offset(736, 368),
    61: const Offset(637, 360),
    62: const Offset(527, 380),
    63: const Offset(449, 486),
    64: const Offset(532, 587),
    65: const Offset(638, 597),
    66: const Offset(737, 596),
    67: const Offset(835, 597),
    68: const Offset(935, 596),
    69: const Offset(1034, 595),
    70: const Offset(1132, 597),
    71: const Offset(1307, 550),
    72: const Offset(1307, 500),
  };

  // Dimensiones originales de la imagen del tablero
  static const double _boardOriginalWidth = 1920.0;
  static const double _boardOriginalHeight = 1080.0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final token = ref.read(authProvider).token;
      if (token != null) {
        // Conectamos el WebSocket del juego usando el gameId guardado en el estado del lobby 
        // (si se viene de lobby) y el token de autenticación.
        final gameId = ref.read(lobbyProvider).gameId ?? '1';
        ref.read(webSocketProvider).connect(gameId, token);
      }
    });
  }

  @override
  void dispose() {
    // Desconexión limpia del WebSocket cuando se destruye la pantalla (Issue #25)
    ref.read(webSocketProvider).disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final activePlayerId = gameState.turnOrder[gameState.activePlayerIndex];
    final myUsername = ref.watch(authProvider).username;
    final isMyTurn = myUsername == activePlayerId;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calcular el factor de escala para que el tablero quepa en la ventana
          final scaleX = constraints.maxWidth / _boardOriginalWidth;
          final scaleY = constraints.maxHeight / _boardOriginalHeight;
          final scale = scaleX < scaleY ? scaleX : scaleY;

          final boardDisplayWidth = _boardOriginalWidth * scale;
          final boardDisplayHeight = _boardOriginalHeight * scale;

          return Stack(
            children: [
              // ============================================
              // FONDO: Tablero centrado con escala fija
              // ============================================
              Positioned.fill(
                child: Container(color: const Color(0xFF1a1a2e)),
              ),
              Center(
                child: SizedBox(
                  width: boardDisplayWidth,
                  height: boardDisplayHeight,
                  child: Stack(
                    children: [
                      // Imagen del tablero escalada
                      Positioned.fill(
                        child: Image.asset(
                          'assets/images/board/tablero_def.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      // Capa de jugadores (animada)
                      ...gameState.players.map((p) {
                        final index = p.currentTileIndex;
                        final tileCenter = tileCenters[index] ?? Offset.zero;

                        final playersHere = gameState.players
                            .where((player) => player.currentTileIndex == index)
                            .toList();
                        final total = playersHere.length;
                        final slot = playersHere.indexOf(p);

                        // Escala
                        final double shrinkFactor = total == 1
                            ? 1.0
                            : total == 2
                                ? 0.70
                                : total == 3
                                    ? 0.55
                                    : 0.45;
                        final spriteSize = 80.0 * scale * shrinkFactor;
                        
                        bool isFacingRight = true;
                        if (index > 0) {
                          final current = tileCenters[index];
                          final prev = tileCenters[index - 1];
                          if (current != null &&
                              prev != null &&
                              current != const Offset(0, 0) &&
                              prev != const Offset(0, 0)) {
                            isFacingRight = current.dx >= prev.dx;
                          }
                        }

                        // Offsets para no solaparse
                        Offset playerOffset = Offset.zero;
                        final spread = 80.0 * scale * 0.5; // Relativo al tamaño base
                        if (total == 2) {
                          playerOffset = slot == 0
                              ? Offset(-spread, 0)
                              : Offset(spread, 0);
                        } else if (total == 3) {
                          if (slot == 0) {
                            playerOffset = Offset(-spread, -spread * 0.4);
                          } else if (slot == 1) {
                            playerOffset = Offset(spread, -spread * 0.4);
                          } else {
                            playerOffset = Offset(0, spread * 0.6);
                          }
                        } else if (total >= 4) {
                          if (slot == 0) {
                            playerOffset = Offset(-spread, -spread * 0.5);
                          } else if (slot == 1) {
                            playerOffset = Offset(spread, -spread * 0.5);
                          } else if (slot == 2) {
                            playerOffset = Offset(-spread, spread * 0.5);
                          } else {
                            playerOffset = Offset(spread, spread * 0.5);
                          }
                        }

                        // Calculamos top/left final superponiendo al centro
                        final scaledX = tileCenter.dx * scale + playerOffset.dx;
                        final scaledY = tileCenter.dy * scale + playerOffset.dy;

                        final leftPos = scaledX - spriteSize / 2;
                        final topPos = scaledY - spriteSize * 0.8;

                        return AnimatedPositioned(
                          key: ValueKey(p.id),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                          left: leftPos,
                          top: topPos,
                          width: spriteSize,
                          height: spriteSize,
                          child: Image.asset(
                            getCharacterImagePath(
                                p.characterClass, isFacingRight),
                            fit: BoxFit.contain,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // ============================================
              // UI OVERLAY: DEBUG - Mostrar estado detallado (top-center)
              // ============================================
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1a1a2e),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF00FF00), width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Línea 1: Jugador actual
                        Text(
                          '👤 ${gameState.players.firstWhere((p) => p.id == activePlayerId).username} (ID: $activePlayerId)',
                          style: const TextStyle(
                            color: Color(0xFFFFFFFF),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Línea 2: Posición actual
                        Text(
                          '📍 Casilla: ${gameState.players.firstWhere((p) => p.id == activePlayerId).currentTileIndex} / 72',
                          style: const TextStyle(
                            color: Color(0xFF00FF00),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Línea 3: Dado y turno
                        Text(
                          '🎲 Dado: ${gameState.lastDiceResult ?? "—"} | Turno: ${gameState.activePlayerIndex % gameState.turnOrder.length + 1}',
                          style: TextStyle(
                            color: gameState.lastDiceResult != null
                                ? const Color(0xFFFFD700)
                                : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Línea 4: Fase del juego
                        Text(
                          '⚙️ Fase: ${gameState.currentPhase.name} | Ronda: ${gameState.currentRound}',
                          style: const TextStyle(
                            color: Color(0xFF00CCFF),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ============================================
              // UI OVERLAY: Panel de jugadores (top-left)
              // ============================================
              Positioned(
                top: 16,
                left: 16,
                child: _buildPlayerPanel(gameState, activePlayerId, myUsername ?? ''),
              ),

              // ============================================
              // UI OVERLAY: Botón TIENDA (bottom-left)
              // ============================================
              Positioned(
                bottom: 16,
                left: 16,
                child: _buildPixelButton(
                  text: 'TIENDA',
                  onPressed: () {
                    setState(() => _isShopOpen = true);
                  },
                ),
              ),

              // ============================================
              // UI OVERLAY: Dado + Botón TIRAR DADO (bottom-right)
              // ============================================
              Positioned(
                bottom: 16,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Display del dado
                    _buildDiceDisplay(gameState),
                    const SizedBox(width: 12),
                    // Botón tirar dado
                    _buildPixelButton(
                      text: 'TIRAR DADO',
                      onPressed: (gameState.currentPhase == GamePhase.finished || !isMyTurn)
                          ? null
                          : () {
                              final gameId = ref.read(lobbyProvider).gameId ?? '1';
                              ref.read(webSocketProvider).rollDiceCommand(gameId, myUsername!);
                            },
                    ),
                  ],
                ),
              ),

              // ============================================
              // UI OVERLAY: Panel de Inventario (bottom-left, encima de tienda)
              // ============================================
              Positioned(
                bottom: 80,
                left: 16,
                child: InventoryPanel(
                  items: gameState.players.firstWhere((p) => p.id == activePlayerId).itemInventory,
                ),
              ),

              // ============================================
              // UI OVERLAY: Modal de la Tienda
              // ============================================
              if (_isShopOpen)
                Positioned.fill(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isShopOpen = false),
                        child: Container(color: Colors.black.withOpacity(0.6)),
                      ),
                      Center(
                        child: ShopModal(
                          playerCoins: gameState.players.firstWhere((p) => p.id == activePlayerId).coins,
                          onClose: () => setState(() => _isShopOpen = false),
                        ),
                      ),
                    ],
                  ),
                ),

              // ============================================
              // UI OVERLAY: Minijuego
              // ============================================
              if (gameState.currentPhase == GamePhase.minigameOrder ||
                  gameState.currentPhase == GamePhase.minigameTile)
                const Positioned.fill(
                  child: MinigameOverlay(),
                ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // WIDGET: Panel de Jugadores
  // ============================================================
  Widget _buildPlayerPanel(GameState gameState, String activePlayerId, String myUsername) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xDD2D1B4E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6C3FA0), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF6C3FA0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: const Text(
              'JUGADORES',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Lista de jugadores
          ...gameState.players.map((player) {
            final isActive = player.id == activePlayerId;
            final isMe = player.id == myUsername || player.username == myUsername;
            return _buildPlayerRow(player, isActive, isMe);
          }),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Player player, bool isActive, bool isMe) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0x33FFFFFF)
            : (isMe ? Colors.green.withOpacity(0.15) : Colors.transparent),
        border: Border(
          bottom: const BorderSide(color: Color(0x33FFFFFF), width: 1),
          left: isMe ? const BorderSide(color: Colors.greenAccent, width: 4) : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          // Avatar miniatura
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isActive
                    ? Colors.amber
                    : const Color(0x55FFFFFF),
                width: isActive ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.asset(
                getCharacterImagePath(player.characterClass, true),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Nombre y clase
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.username + (isMe ? ' (TÚ)' : ''),
                  style: TextStyle(
                    color: isMe 
                        ? Colors.greenAccent 
                        : (isActive ? Colors.amber : Colors.white),
                    fontWeight: (isActive || isMe) ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _getClassName(player.characterClass),
                  style: const TextStyle(
                    color: Color(0xAAFFFFFF),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Monedas
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 2),
              Text(
                '${player.coins}',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getClassName(CharacterClass charClass) {
    switch (charClass) {
      case CharacterClass.videojugador:
        return 'VIDEOJUGADOR';
      case CharacterClass.banquero:
        return 'BANQUERO';
      case CharacterClass.escapista:
        return 'ESCAPISTA';
      case CharacterClass.vidente:
        return 'VIDENTE';
    }
  }

  // ============================================================
  // WIDGET: Dado display
  // ============================================================
  Widget _buildDiceDisplay(GameState gameState) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xDD2D1B4E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6C3FA0), width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono del dado
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF333333), width: 2),
            ),
            child: Center(
              child: Text(
                gameState.lastDiceResult != null
                    ? _getDiceFace(gameState.lastDiceResult!)
                    : '🎲',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Icono del turno
          const Text(
            '🔄',
            style: TextStyle(fontSize: 20),
          ),
        ],
      ),
    );
  }

  String _getDiceFace(int value) {
    switch (value) {
      case 1: return '⚀';
      case 2: return '⚁';
      case 3: return '⚂';
      case 4: return '⚃';
      case 5: return '⚄';
      case 6: return '⚅';
      default: return '🎲';
    }
  }

  // ============================================================
  // WIDGET: Botón con sprite morado pixel art
  // ============================================================
  Widget _buildPixelButton({
    required String text,
    VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 160,
        height: 52,
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: AssetImage('assets/images/ui/btn_morado.png'),
            fit: BoxFit.fill,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 2,
              shadows: [
                Shadow(
                  color: Color(0xFF000000),
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Función para devolver un color dado un personaje
Color getCharacterColor(CharacterClass charClass) {
  switch (charClass) {
    case CharacterClass.banquero:
      return Colors.green;
    case CharacterClass.vidente:
      return Colors.purple;
    case CharacterClass.escapista:
      return Colors.black;
    case CharacterClass.videojugador:
      return Colors.orange;
  }
}

// Función para devolver la ruta del sprite png de un personaje en el tablero
String getCharacterImagePath(CharacterClass charClass, bool isFacingRight) {
  final suffix = isFacingRight ? 'der' : 'izq';
  switch (charClass) {
    case CharacterClass.banquero:
      return 'assets/images/characters/tablero/banquero_t_$suffix.png';
    case CharacterClass.vidente:
      return 'assets/images/characters/tablero/vidente_t_$suffix.png';
    case CharacterClass.escapista:
      return 'assets/images/characters/tablero/escapista_t_$suffix.png';
    case CharacterClass.videojugador:
      return 'assets/images/characters/tablero/videojugador_t_$suffix.png';
  }
}