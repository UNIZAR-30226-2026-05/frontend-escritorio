import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/game_provider.dart';
import '../domain/gamemodels.dart';
import '../data/websocket_service.dart';
import '../../auth/presentation/controllers/auth_provider.dart';
import '../../lobby/presentation/controllers/lobby_provider.dart';

import '../../shop/presentation/controllers/shop_providers.dart';
import '../../shop/data/shop_repository.dart';
import 'widgets/minigame_overlay.dart';
import 'widgets/banquero_modal.dart';
import 'widgets/vidente_modal.dart';
import 'widgets/win_screen_modal.dart';
import 'widgets/ruleta_modal.dart';
import 'widgets/inventory_panel.dart';

// BoardScreen — Pantalla principal del tablero de juego
// Layout fijo con tablero centrado y paneles UI superpuestos
class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({super.key});

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  bool _isShopOpen = false;
  Timer? _choiceTimer;
  int _choiceCountdown = 10;
  bool _hasRolledThisTurn = false;
  bool _debugShowWinScreen = false;
  bool _debugShowRuleta = false;
  String _debugRuletaItem = 'Barrera'; // Default

  // Estado de la habilidad del banquero
  bool _isBanqueroOpen = false; // esta abierta la habilidad
  bool _hasUsedBanqueroSkill = false; // se ha usado la habilidad

  // Resultado de dados a mostrar brevemente (animación)
  bool _showingDiceResult = false;
  Timer? _diceResultTimer;

  // Minijuegos para debugear
  final List<String> _debugMinigames = [
    'Reflejos',
    'Tren',
    'Cortar pan',
    'Cronometro ciego',
    'Mayor o Menor',
    'Doble o Nada',
    'Dilema del Prisionero',
    'Test: Fin de Partida',
    'Ruleta',
    'Poker',
  ];

  // Coordenadas de los centros de las casillas en el tablero
  final Map<int, Offset> tileCenters = {
    -1: const Offset(
        129, 952), // Casilla de espera o especial a la izquierda del inicio
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
    _choiceTimer?.cancel();
    super.dispose();
  }

  // Para poder poner/quitar el overlay de debug
  Widget _buildDebugMenu() {
    return Positioned(
      top: 16,
      right: 16,
      child: PopupMenuButton<String>(
        tooltip: 'Testear Minijuegos (Local)',
        // Usamos un color verde o distinto para saber que es de uso local
        icon: const Icon(Icons.bug_report, color: Colors.greenAccent, size: 36),
        color: const Color(0xFF2D1B4E),
        onSelected: (String minigame) {
          if (minigame == 'Test: Fin de Partida') {
            setState(() => _debugShowWinScreen = true);
          } else if (minigame == 'Ruleta') {
            // Seleccionamos un ítem al azar del catálogo para testear
            final items = ShopRepository.catalog.map((i) => i.name).toList();
            final randomItem = items[Random().nextInt(items.length)];
            setState(() {
              _debugRuletaItem = randomItem;
              _debugShowRuleta = true;
            });
          } else {
            // Llamamos a nuestro nuevo método local
            ref.read(gameProvider.notifier).startDebugMinigameLocal(minigame);
          }
        },
        itemBuilder: (BuildContext context) {
          return _debugMinigames.map((String choice) {
            return PopupMenuItem<String>(
              value: choice,
              child: Text(
                choice,
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Retro Gaming',
                    fontSize: 12),
              ),
            );
          }).toList();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final activePlayerId = (gameState.turnOrder.isNotEmpty &&
            gameState.activePlayerIndex >= 0 &&
            gameState.activePlayerIndex < gameState.turnOrder.length)
        ? gameState.turnOrder[gameState.activePlayerIndex]
        : '';
    final myUsername = ref.watch(authProvider).username;
    final isMyTurn = myUsername == activePlayerId && activePlayerId.isNotEmpty;

    // Arrancar / cancelar el timer de selección cuando el Videojugador recibe sus opciones
    ref.listen(
      gameProvider.select((s) => s.minigameChoices),
      (prev, next) {
        final hasChoices = next != null && next.isNotEmpty;
        if (hasChoices && (prev == null || prev.isEmpty)) {
          // Acaban de aparecer las opciones → reset y arrancamos cuenta atrás
          setState(() => _choiceCountdown = 10);
          _choiceTimer?.cancel();
          _choiceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
            if (!mounted) {
              t.cancel();
              return;
            }
            setState(() => _choiceCountdown--);
            if (_choiceCountdown <= 0) {
              t.cancel();
              // Selección aleatoria automática
              final choices = ref.read(gameProvider).minigameChoices ?? [];
              if (choices.isNotEmpty) {
                final random = choices[
                    DateTime.now().millisecondsSinceEpoch % choices.length];
                ref.read(webSocketProvider).sendMinigameChoice(random);
                ref.read(gameProvider.notifier).clearMinigameChoices();
              }
            }
          });
        } else if (!hasChoices) {
          // Las opciones desaparecieron → cancelamos el timer
          _choiceTimer?.cancel();
        }
      },
    );

    // Escuchar desconexiones de jugadores para mostrar SnackBar reactivo
    ref.listen(
      gameProvider.select((s) => s.players),
      (prev, next) {
        if (prev == null) return;
        for (var pNext in next) {
          if (!pNext.isConnected) {
            // Buscamos si antes estaba conectado
            final pPrev = prev.firstWhere((p) => p.id == pNext.id,
                orElse: () => pNext.copyWith(isConnected: true));
            if (pPrev.isConnected) {
              // Notificación de desconexión
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'El jugador ${pNext.username} se ha desconectado de la partida',
                      style: const TextStyle(fontFamily: 'Retro Gaming')),
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 4)));
            }
          }
        }
      },
    );

    // Resetear _hasRolledThisTurn cuando cambia el turno,
    // vuelve la fase al tablero o es un juego de 1 jugador
    ref.listen(
      gameProvider.select((s) => '${s.activePlayerIndex}_${s.currentPhase}'),
      (prev, next) {
        if (prev != next && mounted) {
          setState(() => _hasRolledThisTurn = false);
          setState(() => _hasUsedBanqueroSkill = false);
        }
      },
    );

    // Mostrar el resultado de los dados durante 1.2 segundos al recibir un resultado
    ref.listen(
      gameProvider.select((s) =>
          (s.lastDice1, s.lastDice2, s.lastDiceResult, s.lastDiceRollId)),
      (prev, next) {
        final (d1, d2, total, rollId) = next;
        // Solo mostramos si hay un resultado válido y no es una corrección (total > 0)
        if (total != null && total > 0 && mounted) {
          _diceResultTimer?.cancel();
          setState(() => _showingDiceResult = true);
          _diceResultTimer = Timer(const Duration(milliseconds: 2200), () {
            if (mounted) {
              setState(() => _showingDiceResult = false);
            }
          });
        }
      },
    );

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
              // FONDO: Tablero centrado con escala fija
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

                        // Escala: No los hacemos diminutos, solo un poco más pequeños para que quepan (85%).
                        final double shrinkFactor = total == 1 ? 1.0 : 0.85;
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

                        // Offsets para posicionamiento lógico (lado a lado y delante/detrás)
                        // Slots más altos tendrán mayor 'dy' para aparecer "delante" visualmente en el Stack.
                        Offset playerOffset = Offset.zero;
                        final double stepX = 25.0 * scale;
                        final double stepY = 15.0 * scale;

                        if (total == 2) {
                          // Uno atrás-izquierda, otro adelante-derecha
                          playerOffset = slot == 0
                              ? Offset(-stepX, -stepY)
                              : Offset(stepX, stepY);
                        } else if (total == 3) {
                          // Dos atrás, uno adelante centrado
                          if (slot == 0) {
                            playerOffset = Offset(-stepX, -stepY);
                          } else if (slot == 1) {
                            playerOffset = Offset(stepX, -stepY);
                          } else {
                            playerOffset = Offset(0, stepY);
                          }
                        } else if (total >= 4) {
                          // Formación en cuadrícula/rombo escalonado
                          if (slot == 0) {
                            playerOffset = Offset(-stepX, -stepY);
                          } else if (slot == 1) {
                            playerOffset = Offset(stepX, -stepY);
                          } else if (slot == 2) {
                            playerOffset = Offset(-stepX * 0.6, stepY);
                          } else {
                            playerOffset = Offset(stepX * 0.6, stepY);
                          }
                        }

                        // Calculamos top/left final superponiendo al centro
                        final scaledX = tileCenter.dx * scale + playerOffset.dx;
                        final scaledY = tileCenter.dy * scale + playerOffset.dy;

                        final leftPos = scaledX - spriteSize / 2;
                        final topPos = scaledY - spriteSize * 0.8;

                        return AnimatedPositioned(
                          key: ValueKey(p.id),
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                          left: leftPos,
                          top: topPos,
                          width: spriteSize,
                          height: spriteSize,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // Drop-shadow oval underneath the token
                              Positioned(
                                bottom: -spriteSize * 0.05,
                                child: Container(
                                  width: spriteSize * 0.8,
                                  height: spriteSize * 0.15,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(50),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // The penguin sprite
                              Image.asset(
                                getCharacterImagePath(
                                    p.characterClass, isFacingRight),
                                fit: BoxFit.contain,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // UI OVERLAY: Panel de jugadores y Inventario (top-left)
              Positioned(
                top: 16,
                left: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPlayerPanel(
                        gameState, activePlayerId, myUsername ?? ''),
                    const SizedBox(height: 16),
                    // Inventario del Jugador Local
                    InventoryPanel(
                      items: gameState.players
                          .firstWhere((p) => p.username == myUsername,
                              orElse: () => gameState.players.first)
                          .itemInventory,
                    ),
                  ],
                ),
              ),
              // UI OVERLAY: Menú Debug (top-right)
              _buildDebugMenu(),

              // UI OVERLAY: Botones Interactivos (bottom-left)
              Positioned(
                bottom: 16,
                left: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Botón de Habilidad (Aparece solo si eres Banquero y es tu turno)
                    if (isMyTurn &&
                        gameState.currentPhase == GamePhase.boardTurn &&
                        !_hasRolledThisTurn &&
                        !_hasUsedBanqueroSkill &&
                        gameState.players
                                .firstWhere((p) => p.username == myUsername)
                                .characterClass ==
                            CharacterClass.banquero) ...[
                      _buildPixelButton(
                        text: 'HABILIDAD',
                        onPressed: () {
                          setState(() => _isBanqueroOpen = true);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Botón Tienda (Siempre visible)
                    _buildPixelButton(
                      text: 'TIENDA',
                      onPressed: () {
                        setState(() => _isShopOpen = true);
                      },
                    ),
                  ],
                ),
              ),

              // El Modal de la tienda se movió más abajo para prioridad de z-index

              // UI OVERLAY: Dado (Solo si es mi turno y no he tirado aun)
              if (isMyTurn &&
                  gameState.currentPhase == GamePhase.boardTurn &&
                  !_hasRolledThisTurn &&
                  !gameState.isMovementActive &&
                  !gameState.isWaitingForMinigameChoice &&
                  (gameState.minigameChoices == null ||
                      gameState.minigameChoices!.isEmpty))
                _buildCenterDiceOverlay(gameState, myUsername ?? ''),

              // UI OVERLAY: Resultado de dados Animado
              if (_showingDiceResult) _buildDiceResultOverlay(gameState),

              // UI OVERLAY: Elegir minijuego (Videojugador)
              if (gameState.minigameChoices != null &&
                  gameState.minigameChoices!.isNotEmpty)
                _buildVideojugadorChoiceOverlay(gameState, myUsername ?? '')

              // UI OVERLAY: Espera para no-Videojugadores
              else if (gameState.isWaitingForMinigameChoice)
                _buildWaitingForVideojugadorOverlay(gameState),

              // UI OVERLAY: Minijuego
              if (gameState.currentPhase == GamePhase.minigameOrder ||
                  gameState.currentPhase == GamePhase.minigameTile)
                const Positioned.fill(
                  child: MinigameOverlay(),
                ),

              // UI OVERLAY: Modal de Ruleta
              if (gameState.obtainedItemName != null && !gameState.isMovementActive)
                Positioned.fill(
                  child: Stack(
                    children: [
                      Container(color: Colors.black.withValues(alpha: 0.6)),
                      Center(
                        child: RuletaModal(
                          itemName: gameState.obtainedItemName!,
                          onClose: () {
                            // Ocultamos la ruleta
                            ref.read(gameProvider.notifier).hideObtainedItem();
                            // AÑADIDO: Avisamos al backend que hemos terminado la casilla
                            ref.read(webSocketProvider).sendEndRound();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              // UI OVERLAY: Modal de la Tienda (ENCIMA DEL TABLERO)
              if (_isShopOpen)
                Positioned.fill(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isShopOpen = false),
                        child: Container(
                            color: Colors.black.withValues(alpha: 0.6)),
                      ),
                      Center(
                        child: ShopModal(
                          playerCoins: gameState.players
                              .firstWhere((p) => p.id == activePlayerId)
                              .coins,
                          onClose: () => setState(() => _isShopOpen = false),
                        ),
                      ),
                    ],
                  ),
                ),

              // UI OVERLAY: Modal del Banquero (ENCIMA DEL TABLERO)
              if (_isBanqueroOpen)
                Positioned.fill(
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _isBanqueroOpen = false),
                        child: Container(
                            color: Colors.black.withValues(alpha: 0.6)),
                      ),
                      Center(
                        child: BanqueroModal(
                          onClose: () =>
                              setState(() => _isBanqueroOpen = false),
                          onSkillUsed: () =>
                              setState(() => _hasUsedBanqueroSkill = true),
                        ),
                      ),
                    ],
                  ),
                ),

              // UI OVERLAY: Modal de la Vidente (ENCIMA DEL TABLERO)
              if (gameState.videnteDiceResults != null)
                Positioned.fill(
                  child: Stack(
                    children: [
                      Container(color: Colors.black.withValues(alpha: 0.6)),
                      Center(
                        child: VidenteModal(
                          diceResults: gameState.videnteDiceResults!,
                          onClose: () =>
                              ref.read(gameProvider.notifier).hideVidenteDice(),
                        ),
                      ),
                    ],
                  ),
                ),

              // UI OVERLAY: Pantalla de Ganador (FIN DE PARTIDA)
              if ((gameState.currentPhase == GamePhase.finished &&
                      gameState.winnerName != null) ||
                  _debugShowWinScreen)
                Positioned.fill(
                  child: Stack(
                    children: [
                      // Fondo oscurecido
                      Container(color: Colors.black.withValues(alpha: 0.85)),
                      Center(
                        child: WinScreenModal(
                          rankedPlayers: [...gameState.players]..sort(
                              (a, b) => b.currentTileIndex
                                  .compareTo(a.currentTileIndex),
                            ),
                          onClose: _debugShowWinScreen
                              ? () => setState(() => _debugShowWinScreen = false)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),

              // UI OVERLAY: Ruleta de Objetos (DEBUG)
              if (_debugShowRuleta)
                Positioned.fill(
                  child: Stack(
                    children: [
                      // Fondo oscurecido
                      Container(color: Colors.black.withValues(alpha: 0.85)),
                      Center(
                        child: RuletaModal(
                          itemName: _debugRuletaItem,
                          isDebug: true,
                          onClose: () =>
                              setState(() => _debugShowRuleta = false),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // WIDGET: Overlay de dados en el centro de la pantalla
  // Solo se muestra cuando es el turno del jugador local
  Widget _buildCenterDiceOverlay(GameState gameState, String myUsername) {
    // Inferir el tipo de dado extra a partir de la posición en el ranking
    final myRankIndex = gameState.turnOrder.indexOf(myUsername);
    final myRank = myRankIndex + 1; // 1-indexed

    // REGLA: En la primera ronda NO hay dados especiales, solo uno.
    final bool isRoundOne = gameState.currentRound <= 1;
    final hasTwoDice =
        !isRoundOne && myRank != 4 && myRank != 0; // rank 1-3 tienen dado extra

    final gameId = ref.read(lobbyProvider).gameId ?? '1';

    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Texto de instrucción
            const Text(
              'ES TU TURNO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 30),
            // Fila de dados
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDiceWidget(
                  diceColor: Colors.white,
                  borderColor: const Color(0xFF444466),
                  label: '1-6',
                  labelColor: Colors.black54,
                ),
                if (hasTwoDice) ...[
                  const SizedBox(width: 28),
                  _buildDiceWidget(
                    diceColor: _extraDiceColor(myRank),
                    borderColor: _extraDiceBorderColor(myRank),
                    label: _extraDiceLabel(myRank),
                    labelColor: _extraDiceLabelColor(myRank),
                    glowColor: _extraDiceGlowColor(myRank),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 40),
            // Botón específico para tirar
            _buildPixelButton(
              text: 'TIRAR DADOS',
              onPressed: () {
                setState(() => _hasRolledThisTurn = true);
                ref.read(webSocketProvider).rollDiceCommand(gameId, myUsername);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Widget individual de un dado (icono cuadrado con estilo)
  Widget _buildDiceWidget({
    required Color diceColor,
    required Color borderColor,
    required String label,
    required Color labelColor,
    Color? glowColor,
  }) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: diceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor.withValues(alpha: 0.6),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '?',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: Colors.black38,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: labelColor,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: Overlay de resultado de dados (Animado)
  Widget _buildDiceResultOverlay(GameState gameState) {
    final d1 = gameState.lastDice1;
    final d2 = gameState.lastDice2;
    final total = gameState.lastDiceResult ?? (d1 + d2);

    // Obtener el ranking del jugador que acaba de tirar para los colores del dado 2
    final myRankIndex = gameState.activePlayerIndex;
    final rank = myRankIndex + 1;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              decoration: BoxDecoration(
                color: const Color(0xEE1a1a2e),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5), width: 2),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black54, blurRadius: 20, spreadRadius: 5)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'RESULTADO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDiceFace(d1, Colors.white, Colors.black87),
                      if (d2 > 0) ...[
                        const SizedBox(width: 20),
                        _buildDiceFace(
                          d2,
                          _extraDiceColor(rank),
                          _extraDiceLabelColor(rank),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '$total',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.orange, blurRadius: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiceFace(int value, Color bgColor, Color textColor) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          )
        ],
      ),
      child: Center(
        child: Text(
          '$value',
          style: TextStyle(
            color: textColor,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Helpers para el color del dado extra por ranking
  Color _extraDiceColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Oro
      case 2:
        return const Color(0xFFC0C0C0); // Plata
      case 3:
        return const Color(0xFFCD7F32); // Bronce
      default:
        return Colors.white;
    }
  }

  Color _extraDiceBorderColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFB8860B);
      case 2:
        return const Color(0xFF909090);
      case 3:
        return const Color(0xFF8B4513);
      default:
        return Colors.grey;
    }
  }

  Color _extraDiceGlowColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.blueGrey;
      case 3:
        return Colors.orange;
      default:
        return Colors.white;
    }
  }

  String _extraDiceLabel(int rank) {
    switch (rank) {
      case 1:
        return '1-6 ORO';
      case 2:
        return '1-4 PLATA';
      case 3:
        return '1-2 BRONCE';
      default:
        return '';
    }
  }

  Color _extraDiceLabelColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFF7A5C00);
      case 2:
        return const Color(0xFF505050);
      case 3:
        return const Color(0xFF5C2800);
      default:
        return Colors.black54;
    }
  }

  // WIDGET: Overlay de selección de minijuego (Videojugador)
  Widget _buildVideojugadorChoiceOverlay(
      GameState gameState, String myUsername) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xDD2D1B4E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purpleAccent, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TU HABILIDAD',
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ELIGE EL SIGUIENTE MINIJUEGO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // Cuenta atrás
                Text(
                  '$_choiceCountdown',
                  style: TextStyle(
                    color:
                        _choiceCountdown <= 3 ? Colors.redAccent : Colors.amber,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: gameState.minigameChoices!.map((choice) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildPixelButton(
                        text: choice.toUpperCase(),
                        onPressed: () {
                          _choiceTimer?.cancel();
                          ref
                              .read(webSocketProvider)
                              .sendMinigameChoice(choice);
                          ref
                              .read(gameProvider.notifier)
                              .clearMinigameChoices();
                        },
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET: Overlay de espera (jugadores sin habilidad de elección)
  Widget _buildWaitingForVideojugadorOverlay(GameState gameState) {
    // Tomamos los nombres de los minijuegos del gameState si están, sino usamos placeholders
    final choices = gameState.minigameChoices ?? ['MINIJUEGO', 'MINIJUEGO'];
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xDD2D1B4E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'EL VIDEOJUGADOR ESTÁ ELIGIENDO...',
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'SIGUIENTE MINIJUEGO',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: choices.map((choice) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // Botón bloqueado visualmente (sin onPressed)
                      child: Opacity(
                        opacity: 0.4,
                        child: _buildPixelButton(
                          text: choice.toUpperCase(),
                          onPressed: null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.amber,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET: Panel de Jugadores
  Widget _buildPlayerPanel(
      GameState gameState, String activePlayerId, String myUsername) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: gameState.players.map((player) {
        final isActive = player.id == activePlayerId;
        final isMe = player.id == myUsername || player.username == myUsername;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildPlayerRow(player, isActive, isMe),
        );
      }).toList(),
    );
  }

  Widget _buildPlayerRow(Player player, bool isActive, bool isMe) {
    // Colores basados en la imagen
    const Color cardBgColor = Color(0xFF422B7A);
    const Color activeBorderColor = Color(0xFF3CD37D);
    const Color inactiveBorderColor = Colors.white;
    final Color badgeColor = _getBadgeColor(player.characterClass);

    Widget avatarWidget = Image.asset(
      getCharacterPerfilPath(player.characterClass),
      fit: BoxFit.contain,
    );

    if (!player.isConnected) {
      avatarWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      0.5, 0,
        ]),
        child: avatarWidget,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      transform: isActive ? Matrix4.diagonal3Values(1.05, 1.05, 1.0) : Matrix4.identity(),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardBgColor,
        border: Border.all(
          color: isActive ? activeBorderColor : inactiveBorderColor,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.8),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar miniatura
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeColor,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: avatarWidget,
                ),
                if (player.penaltyTurns > 0)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.lock,
                          color: Colors.redAccent, size: 16),
                    ),
                  ),
                if (!player.isConnected)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.wifi_off,
                          color: Colors.redAccent, size: 16),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Nombre y clase
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    player.username,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      fontFamily: 'Retro Gaming',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getClassName(player.characterClass).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Retro Gaming',
                    color: Colors.white70,
                    fontSize: 8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Monedas
          Text(
            '${player.coins}e',
            style: const TextStyle(
              fontFamily: 'Retro Gaming',
              color: Color(0xFFFFD700),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(CharacterClass charClass) {
    switch (charClass) {
      case CharacterClass.banquero:
        return const Color(0xFFFFB800);
      case CharacterClass.videojugador:
        return const Color(0xFF3886FE);
      case CharacterClass.vidente:
        return const Color(0xFFC74CFF);
      case CharacterClass.escapista:
        return const Color(0xFF0BA745);
    }
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

  // WIDGET: Botón con sprite morado pixel art
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
              color: Colors.black.withValues(alpha: 0.4),
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

String getCharacterPerfilPath(CharacterClass charClass) {
  switch (charClass) {
    case CharacterClass.banquero:
      return 'assets/images/characters/general/banquero_perfil.png';
    case CharacterClass.vidente:
      return 'assets/images/characters/general/vidente_perfil.png';
    case CharacterClass.escapista:
      return 'assets/images/characters/general/escapista_perfil.png';
    case CharacterClass.videojugador:
      return 'assets/images/characters/general/videojugador_perfil.png';
  }
}
