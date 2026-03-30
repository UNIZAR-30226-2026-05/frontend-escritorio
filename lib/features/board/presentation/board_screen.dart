import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/game_provider.dart';
import '../domain/gamemodels.dart';
import '../data/websocket_service.dart';
import '../../auth/presentation/controllers/auth_provider.dart';

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
  final String _gameId = "1";
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
    35: const Offset(255, 242),
    36: const Offset(203, 332),
    37: const Offset(181, 442),
    38: const Offset(192, 544),
    39: const Offset(239, 641),
    40: const Offset(337, 707),
    41: const Offset(441, 721),
    42: const Offset(539, 721),
    43: const Offset(640, 721),
    44: const Offset(738, 722),
    45: const Offset(836, 720),
    46: const Offset(935, 720),
    47: const Offset(1035, 721),
    48: const Offset(1131, 722),
    49: const Offset(1232, 722),
    50: const Offset(1331, 720),
    51: const Offset(1443, 694),
    52: const Offset(1519, 604),
    53: const Offset(1518, 489),
    54: const Offset(1439, 396),
    55: const Offset(1331, 369),
    56: const Offset(1233, 369),
    57: const Offset(1134, 369),
    58: const Offset(1035, 369),
    59: const Offset(936, 369),
    60: const Offset(837, 369),
    61: const Offset(736, 368),
    62: const Offset(637, 360),
    63: const Offset(527, 380),
    64: const Offset(449, 486),
    65: const Offset(532, 587),
    66: const Offset(638, 597),
    67: const Offset(737, 596),
    68: const Offset(835, 597),
    69: const Offset(935, 596),
    70: const Offset(1034, 595),
    71: const Offset(1132, 597),
    72: const Offset(1307, 550),
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
        ref.read(webSocketProvider).connect(_gameId, token);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final activePlayerId = gameState.turnOrder[gameState.activePlayerIndex];

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
              // UI OVERLAY: Panel de jugadores (top-left)
              // ============================================
              Positioned(
                top: 16,
                left: 16,
                child: _buildPlayerPanel(gameState, activePlayerId),
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
                      onPressed: gameState.currentPhase == GamePhase.finished
                          ? null
                          : () => ref.read(gameProvider.notifier).rollDice(),
                    ),
                  ],
                ),
              ),

              // ============================================
              // UI OVERLAY: Modal de la Tienda
              // ============================================
              if (_isShopOpen) ..._buildShopOverlay(gameState),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // WIDGET: Panel de Jugadores
  // ============================================================
  Widget _buildPlayerPanel(GameState gameState, String activePlayerId) {
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
            return _buildPlayerRow(player, isActive);
          }),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(Player player, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0x33FFFFFF)
            : Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: Color(0x33FFFFFF), width: 1),
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
                  player.username,
                  style: TextStyle(
                    color: isActive ? Colors.amber : Colors.white,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
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

  // ============================================================
  // WIDGET: Overlay de la Tienda (fondo oscuro + modal)
  // ============================================================
  List<Widget> _buildShopOverlay(GameState gameState) {
    return [
      // Fondo oscuro semi-transparente
      Positioned.fill(
        child: GestureDetector(
          onTap: () => setState(() => _isShopOpen = false),
          child: Container(
            color: Colors.black.withOpacity(0.6),
          ),
        ),
      ),
      // Modal centrado
      Center(
        child: _buildShopModal(gameState),
      ),
    ];
  }

  Widget _buildShopModal(GameState gameState) {
    final activePlayerId = gameState.turnOrder[gameState.activePlayerIndex];
    final currentPlayer =
        gameState.players.firstWhere((p) => p.id == activePlayerId);

    return Container(
      width: 520,
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B4E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF6C3FA0),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'TIENDA DE OBJETOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Monedas del jugador actual
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x33FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            '${currentPlayer.coins}',
                            style: const TextStyle(
                              color: Color(0xFFFFD700),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Botón cerrar
                GestureDetector(
                  onTap: () => setState(() => _isShopOpen = false),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0x44FFFFFF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: Text(
                        '✕',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Grid de items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildShopItemCard(
                  icon: '👟',
                  name: 'Avanzar 3 casillas',
                  price: 2,
                  playerCoins: currentPlayer.coins,
                ),
                _buildShopItemCard(
                  icon: '🎲',
                  name: 'Dado de Plata',
                  price: 3,
                  playerCoins: currentPlayer.coins,
                ),
                _buildShopItemCard(
                  icon: '🚧',
                  name: 'Barrera de bloqueo',
                  price: 6,
                  playerCoins: currentPlayer.coins,
                ),
                _buildShopItemCard(
                  icon: '💰',
                  name: 'Robar 2 monedas',
                  price: 3,
                  playerCoins: currentPlayer.coins,
                ),
                _buildShopItemCard(
                  icon: '🎡',
                  name: 'Ruleta',
                  price: 4,
                  playerCoins: currentPlayer.coins,
                ),
                _buildShopItemCard(
                  icon: '🛟',
                  name: 'Salvavidas',
                  price: 3,
                  playerCoins: currentPlayer.coins,
                ),
                _buildShopItemCard(
                  icon: '🛑',
                  name: 'Quitar turno',
                  price: 6,
                  playerCoins: currentPlayer.coins,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItemCard({
    required String icon,
    required String name,
    required int price,
    required int playerCoins,
  }) {
    final canAfford = playerCoins >= price;

    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF3D2660),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x88FFFFFF), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 6),
          // Nombre
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Precio
          Text(
            '${price}¢',
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Botón comprar
          GestureDetector(
            onTap: canAfford
                ? () {
                    // TODO: Implementar lógica de compra
                  }
                : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: canAfford
                    ? const Color(0xFF2E8B57)
                    : const Color(0xFF555555),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: canAfford
                      ? const Color(0xFF3CB371)
                      : const Color(0xFF777777),
                  width: 1,
                ),
              ),
              child: Text(
                'Comprar',
                style: TextStyle(
                  color: canAfford
                      ? Colors.white
                      : const Color(0xFF999999),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
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
