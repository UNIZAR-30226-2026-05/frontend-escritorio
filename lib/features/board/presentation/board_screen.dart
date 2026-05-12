import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'controllers/game_provider.dart';
import '../domain/gamemodels.dart';
import '../data/websocket_service.dart';
import '../../auth/presentation/controllers/auth_provider.dart';
import '../../lobby/presentation/controllers/lobby_provider.dart';

import '../../shop/presentation/controllers/shop_providers.dart';
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
  // Estados locales para la animación de dados
  int _lastHandledDiceId = 0;
  bool _isRolling = false;
  int _tempDice1 = 1;
  int _tempDice2 = 1;
  Timer? _rollTimer;
  StreamSubscription? _wsEventSubscription;

  Timer? _choiceTimer;
  int _choiceCountdown = 10;
  bool _hasRolledThisTurn = false;

  // Estado de la habilidad del banquero
  bool _isBanqueroOpen = false; // esta abierta la habilidad
  bool _hasUsedBanqueroSkill = false; // se ha usado la habilidad

  // Resultado de dados a mostrar brevemente (animación)
  bool _showingDiceResult = false;
  Timer? _diceResultTimer;

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

  late final WebSocketService _wsService;

  @override
  void initState() {
    super.initState();
    _wsService = ref.read(webSocketProvider);
    Future.microtask(() {
      // Inicializamos los jugadores desde los datos del lobby antes de conectar
      final lobbyState = ref.read(lobbyProvider);
      ref.read(gameProvider.notifier).initFromLobby(lobbyState.selectedCharacters);

      final token = ref.read(authProvider).token;
      if (token != null) {
        final gameId = lobbyState.gameId ?? '1';
        _wsService.connect(gameId, token);
      }

      _wsEventSubscription = _wsService.eventStream.listen((event) {
        if (event['type'] == 'info_message') {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(event['message'] ?? '',
                  style: const TextStyle(fontFamily: 'Retro Gaming')),
              backgroundColor: Colors.blueAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _choiceTimer?.cancel();
    _rollTimer?.cancel();
    _wsEventSubscription?.cancel();
    _wsService.disconnect();
    super.dispose();
  }

  void _triggerDiceAnimation(int d1, int d2) {
    _rollTimer?.cancel();
    setState(() {
      _isRolling = true;
    });

    int count = 0;
    _rollTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _tempDice1 = Random().nextInt(6) + 1;
        _tempDice2 = Random().nextInt(6) + 1;
      });
      count++;
      if (count >= 10) {
        timer.cancel();
        setState(() {
          _isRolling = false;
          _tempDice1 = d1;
          _tempDice2 = d2;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final activePlayerId = gameState.activePlayerName ?? '';
    final myUsername = ref.watch(authProvider).username;
    final isMyTurn = myUsername == activePlayerId && activePlayerId.isNotEmpty;

    final me = gameState.players.firstWhere((p) => p.username == myUsername,
        orElse: () => gameState.players.first);
    final bool isBanquero = me.characterClass == CharacterClass.banquero;
    final bool canRobAnyone = gameState.players
        .where((p) => p.username != myUsername)
        .any((p) => p.coins > 0);
    final bool shouldForceBanquero = isMyTurn &&
        isBanquero &&
        !_hasUsedBanqueroSkill &&
        canRobAnyone &&
        gameState.currentPhase == GamePhase.boardTurn &&
        !gameState.isMovementActive &&
        gameState.obtainedItemName == null &&
        (gameState.minigameChoices == null ||
            gameState.minigameChoices!.isEmpty);

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
      gameProvider.select((s) => '${s.activePlayerName}_${s.currentPhase}'),
      (prev, next) {
        if (prev != next && mounted) {
          final prevPlayer = prev?.split('_').first;
          final nextPlayer = next.split('_').first;
          setState(() {
            _hasRolledThisTurn = false;
            // Solo resetear la habilidad del banquero cuando cambia el jugador activo,
            // no cuando la fase cambia por un minijuego de casilla (y luego vuelve).
            if (prevPlayer != nextPlayer) _hasUsedBanqueroSkill = false;
            _isShopOpen = false;
            _isBanqueroOpen = false;
          });
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
                                        color:
                                            Colors.black.withValues(alpha: 0.4),
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
              // UI OVERLAY: Timer de Turno (top-right)
              if (gameState.currentPhase == GamePhase.boardTurn &&
                  (!isMyTurn || !_hasRolledThisTurn) &&
                  !_showingDiceResult &&
                  !gameState.isMovementActive &&
                  !gameState.isWaitingForMinigameChoice &&
                  gameState.obtainedItemName == null &&
                  (gameState.minigameChoices == null ||
                      gameState.minigameChoices!.isEmpty))
                TurnTimerWidget(
                  key: ValueKey(gameState.activePlayerName),
                  onTimeout: () {
                    // Si es mi turno y se acaba el tiempo, forzamos el fin de turno desde el front
                    if (isMyTurn) {
                      ref.read(webSocketProvider).sendEndRound();
                    }
                  },
                ),

              // UI OVERLAY: Botones Interactivos (bottom-left)
              // (Eliminado el botón de habilidad de aquí para moverlo al overlay de dados)

              // El Modal de la tienda se movió más abajo para prioridad de z-index

              // UI OVERLAY: Dado (Se muestra el previo a tirar para todos)
              if (gameState.currentPhase == GamePhase.boardTurn &&
                  (!isMyTurn || !_hasRolledThisTurn) &&
                  !_showingDiceResult &&
                  !gameState.isMovementActive &&
                  !gameState.isWaitingForMinigameChoice &&
                  gameState.obtainedItemName == null &&
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
              if (gameState.obtainedItemName != null)
                Positioned.fill(
                  child: Stack(
                    children: [
                      Container(color: Colors.black.withValues(alpha: 0.6)),
                      Center(
                        child: RuletaModal(
                          itemName: gameState.obtainedItemName!,
                          playerName: gameState.obtainedItemPlayer ?? 'Jugador',
                          isLocalPlayer:
                              gameState.obtainedItemPlayer == myUsername,
                          onClose: () {
                            // Ocultamos la ruleta de la interfaz
                            ref.read(gameProvider.notifier).hideObtainedItem();
                            // El evaluador maestro decide si avanzar turno (sin pasar argumento)
                            ref.read(webSocketProvider).checkAndFinalizeTurn();
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
                          hasRolled: _hasRolledThisTurn,
                          onClose: () => setState(() => _isShopOpen = false),
                        ),
                      ),
                    ],
                  ),
                ),

              // UI OVERLAY: Modal del Banquero (ENCIMA DEL TABLERO)
              if (_isBanqueroOpen || shouldForceBanquero)
                Positioned.fill(
                  child: Stack(
                    children: [
                      if (!shouldForceBanquero)
                        GestureDetector(
                          onTap: () => setState(() => _isBanqueroOpen = false),
                          child: Container(
                              color: Colors.black.withValues(alpha: 0.6)),
                        )
                      else
                        Container(color: Colors.black.withValues(alpha: 0.6)),
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
              if (gameState.currentPhase == GamePhase.finished &&
                  gameState.winnerName != null)
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
                          onClose: null,
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
  // Se muestra para todos, pero los controles solo los ve el jugador activo
  Widget _buildCenterDiceOverlay(GameState gameState, String myUsername) {
    final activePlayerId = gameState.activePlayerName ?? '';
    final bool isMyTurn = activePlayerId == myUsername;

    // Buscar al jugador local para ver su penalización
    final localPlayer = gameState.players.firstWhere(
      (p) => p.username == myUsername,
      orElse: () => gameState.players.first,
    );
    final isPenalized = localPlayer.penaltyTurns > 0;

    // Solo vemos la pantalla de "ESTÁS BLOQUEADO" si es nuestro turno.
    // Si no es nuestro turno, vemos lo que hace el jugador activo.
    if (isPenalized && isMyTurn) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.redAccent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _ProhibitionIcon(size: 64),
              const SizedBox(height: 20),
              const Text(
                'ESTÁS BLOQUEADO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Te quedan ${localPlayer.penaltyTurns} turnos de penalización.\n¿Deseas pasar el turno o comprar un Salvavidas?',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPixelButton(
                    text: 'TIENDA',
                    width: 150,
                    onPressed: () => setState(() => _isShopOpen = true),
                  ),
                  const SizedBox(width: 20),
                  _buildPixelButton(
                    text: 'PASAR TURNO',
                    width: 180,
                    onPressed: () {
                      ref.read(webSocketProvider).sendEndRound();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Inferir el tipo de dado extra a partir de la posición en el ranking del JUGADOR ACTIVO
    final rankIndex = gameState.turnOrder.indexOf(activePlayerId);
    final rank = rankIndex + 1; // 1-indexed

    // Si ha mejorado los dados, visualmente mostramos el dado extra mejorado
    // Regla: 4º (1 dado) -> +Bronce, 3º (Bronce) -> +Plata, 2º (Plata) -> +Oro
    int effectiveRankForExtraDice = rank;
    if (gameState.hasImprovedDice && rank > 1) {
      effectiveRankForExtraDice = rank - 1;
    }

    // REGLA: En la primera ronda NO hay dados especiales por defecto,
    // pero si compras la mejora, TE SALE el de bronce (effectiveRank 3).
    final bool isRoundOne = gameState.currentRound <= 1;
    final bool hasTwoDiceByDefault = !isRoundOne && rank != 4 && rank != 0;

    final bool hasTwoDice = hasTwoDiceByDefault || gameState.hasImprovedDice;

    final gameId = ref.read(lobbyProvider).gameId ?? '1';

    final String labelText =
        hasTwoDice ? _extraDiceLabel(effectiveRankForExtraDice) : '1-6 NORMAL';

    final purchases = gameState.turnPurchasedItems.entries.toList();

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gameState.turnTheftMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent, width: 2),
              ),
              child: Text(
                gameState.turnTheftMessage!,
                style: const TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          if (purchases.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: purchases.map((e) {
                  final itemName = e.key.toUpperCase();
                  final count = e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Retro Gaming',
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        children: [
                          TextSpan(
                              text: isMyTurn
                                  ? 'HAS COMPRADO '
                                  : '${activePlayerId.toUpperCase()} HA COMPRADO '),
                          TextSpan(
                              text: itemName,
                              style: const TextStyle(color: Colors.amber)),
                          if (count > 1)
                            TextSpan(
                              text: ' X$count',
                              style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 650,
                height: 450,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.6), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMyTurn
                          ? 'ES TU TURNO'
                          : 'TURNO DE ${activePlayerId.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      '?',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 10)
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      labelText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                    if (isMyTurn) ...[
                      const SizedBox(height: 40),
                      // Botones de acción del turno
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPixelButton(
                            text: 'TIENDA',
                            width: 140,
                            onPressed: () => setState(() => _isShopOpen = true),
                          ),
                          const SizedBox(width: 20),
                          _buildPixelButton(
                            text: hasTwoDice ? 'TIRAR DADOS' : 'TIRAR DADO',
                            onPressed: () {
                              setState(() => _hasRolledThisTurn = true);
                              ref
                                  .read(webSocketProvider)
                                  .rollDiceCommand(gameId, myUsername);
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: Overlay con el resultado de los dados (Animado)
  Widget _buildDiceResultOverlay(GameState gameState) {
    // Detectar nuevo lanzamiento
    if (gameState.lastDiceRollId != _lastHandledDiceId) {
      _lastHandledDiceId = gameState.lastDiceRollId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerDiceAnimation(gameState.lastDice1, gameState.lastDice2);
      });
    }

    final d1 = _isRolling ? _tempDice1 : gameState.lastDice1;
    final d2 = _isRolling ? _tempDice2 : gameState.lastDice2;
    final total =
        _isRolling ? (d1 + d2) : (gameState.lastDiceResult ?? (d1 + d2));

    // Obtener el ranking del jugador que acaba de tirar para los colores del dado 2
    // El índice ya no lo calculamos localmente, lo obtenemos buscando el nombre en la lista
    final activePlayerId = gameState.activePlayerName ?? '';
    final myRankIndex = gameState.turnOrder.indexOf(activePlayerId);
    final rank = myRankIndex + 1;
    final effectiveRank =
        (gameState.hasImprovedDice && rank > 1) ? rank - 1 : rank;

    final bool isRoundOne = gameState.currentRound <= 1;
    final bool hasTwoDice =
        (!isRoundOne && rank != 4 && rank != 0) || gameState.hasImprovedDice;

    return Positioned.fill(
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                width: 650,
                height: 450,
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.6), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isRolling ? 'TIRANDO...' : 'RESULTADO',
                      style: const TextStyle(
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
                        _buildDiceFace(d1, 4),
                        if (gameState.lastDice2 > 0 ||
                            (_isRolling && hasTwoDice)) ...[
                          const SizedBox(width: 20),
                          _buildDiceFace(d2, effectiveRank),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '$total',
                      style: TextStyle(
                        color: _isRolling ? Colors.white38 : Colors.amber,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        shadows: _isRolling
                            ? []
                            : [
                                const Shadow(
                                    color: Colors.orange, blurRadius: 10),
                              ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiceFace(int value, int rank) {
    String suffix = '';
    if (rank == 1)
      suffix = 'O';
    else if (rank == 2)
      suffix = 'P';
    else if (rank == 3) suffix = 'B';

    // Fallback if value is 0 during rolling
    int displayValue = value > 0 ? value : 1;

    // Evitar buscar assets que no existen durante la animación de random (ej: 6B.png)
    if (rank == 3 && displayValue > 2) {
      displayValue = (displayValue % 2) + 1;
    } else if (rank == 2 && displayValue > 4) {
      displayValue = (displayValue % 4) + 1;
    }

    return SizedBox(
      width: 250,
      height: 250,
      child: Image.asset(
        'assets/images/board/dados/$displayValue$suffix.png',
        fit: BoxFit.contain,
      ),
    );
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
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          0.5,
          0,
        ]),
        child: avatarWidget,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      transform: isActive
          ? Matrix4.diagonal3Values(1.05, 1.05, 1.0)
          : Matrix4.identity(),
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
                  color: const Color(0xFF3CD37D).withValues(alpha: 0.8),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0xFF3CD37D).withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeColor,
              border: Border.all(color: Colors.white24),
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
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        player.username.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Retro Gaming',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${player.coins}¢',
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Retro Gaming',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _getClassName(player.characterClass),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 8,
                    letterSpacing: 1,
                    fontFamily: 'Retro Gaming',
                  ),
                ),
              ],
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

  Widget _buildPixelButton({
    required String text,
    VoidCallback? onPressed,
    double width = 160,
    double height = 52,
    double fontSize = 16,
    String asset = 'assets/images/ui/btn_morado.png',
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(asset),
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
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.08),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                  letterSpacing: 2,
                  shadows: const [
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

class TurnTimerWidget extends StatefulWidget {
  final VoidCallback? onTimeout;
  const TurnTimerWidget({super.key, this.onTimeout});

  @override
  State<TurnTimerWidget> createState() => _TurnTimerWidgetState();
}

class _TurnTimerWidgetState extends State<TurnTimerWidget> {
  int _timeLeft = 25;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeLeft > 0) {
        setState(() => _timeLeft--);
      } else {
        timer.cancel();
        widget.onTimeout?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWarning = _timeLeft <= 5;
    final color = isWarning ? Colors.redAccent : Colors.orangeAccent;
    final progress = _timeLeft / 25.0;

    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        width: 120,
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 3),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'TIEMPO',
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 14,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    color: color,
                    backgroundColor: Colors.white12,
                    strokeWidth: 8,
                  ),
                  Center(
                    child: Text(
                      '$_timeLeft',
                      style: TextStyle(
                        fontFamily: 'Retro Gaming',
                        fontSize: 32,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProhibitionIcon extends StatelessWidget {
  final double size;
  const _ProhibitionIcon({this.size = 64});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ProhibitionPainter(),
    );
  }
}

class _ProhibitionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.12;

    final whiteBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + size.width * 0.06;

    final redFill = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;

    final redStroke = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, whiteBorder);
    canvas.drawCircle(center, radius - strokeWidth / 2, redFill);
    canvas.drawCircle(center, radius - strokeWidth / 2, redStroke);

    final diag = radius * 0.65;
    final whiteLine = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth + size.width * 0.06;
    final redLine = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawLine(
      Offset(center.dx - diag, center.dy + diag),
      Offset(center.dx + diag, center.dy - diag),
      whiteLine,
    );
    canvas.drawLine(
      Offset(center.dx - diag, center.dy + diag),
      Offset(center.dx + diag, center.dy - diag),
      redLine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
