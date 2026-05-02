// MinigameOverlay — Contenedor genérico para todos los minijuegos
//
// Este widget se superpone al tablero cuando la fase de juego cambia
// a minigameOrder o minigameTile. Se encarga de:
//   1. Mostrar una cuenta atrás (3, 2, 1...)
//   2. Cargar el minijuego correspondiente usando la MinigameFactory
//   3. Enviar la puntuación al backend cuando el juego interno termina
//   4. Mostrar el podio de resultados al recibir 'minijuego_resultados'
//   5. Volver automáticamente al tablero tras unos segundos
//

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/game_provider.dart';
import '../../data/websocket_service.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';

import 'minigames/minigame_factory.dart';

class MinigameOverlay extends ConsumerStatefulWidget {
  const MinigameOverlay({super.key});

  @override
  ConsumerState<MinigameOverlay> createState() => _MinigameOverlayState();
}

class _MinigameOverlayState extends ConsumerState<MinigameOverlay> {
  // Estado interno del overlay

  int _countdown = 3;
  bool _countdownFinished = false;
  Timer? _countdownTimer;
  ProviderSubscription<Map<String, dynamic>?>? _resultsSubscription;
  ProviderSubscription<List<dynamic>>? _balancesSubscription;

  // Para Doble o Nada: guardamos la apuesta y si ha terminado
  int? _apuestaDobleNada;
  bool?
      _dobleNadaGanado; // null = esperando resultado, true = ganó, false = perdió

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resultsSubscription = ref.listenManual(
        gameProvider.select((s) => s.minigameResults),
        (prev, next) {
          if (prev == null && next != null) {
            // El cierre automático ocurre 5 s después de mostrar los resultados
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && ref.read(gameProvider).minigameResults != null) {
                ref.read(gameProvider.notifier).finishMinigame();
              }
            });
          }
        },
      );

      // Escuchamos cambios de monedas para detectar el resultado de Doble o Nada
      _balancesSubscription = ref.listenManual(
        gameProvider.select((s) => s.players.map((p) => p.coins).toList()),
        (prev, next) {
          if (!mounted) return;
          final gameState = ref.read(gameProvider);
          if (gameState.minigameName != 'Doble o Nada') return;
          if (_apuestaDobleNada == null) return;
          if (_dobleNadaGanado != null) return; // ya procesado

          final myUsername = ref.read(authProvider).username;
          final myPlayer = gameState.players.firstWhere(
            (p) => p.username == myUsername,
            orElse: () => gameState.players.first,
          );
          final myNewCoins = myPlayer.coins;
          final myPrevCoins = prev != null && prev.length == next.length
              ? prev[gameState.players.indexOf(myPlayer)]
              : null;

          if (myPrevCoins != null) {
            final ganado = myNewCoins > myPrevCoins;
            setState(() => _dobleNadaGanado = ganado);

            // Cerramos automáticamente tras 3 segundos
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                ref.read(gameProvider.notifier).finishMinigame();
                // Delegamos el avance y el end_round al evaluador maestro
                ref.read(webSocketProvider).checkAndFinalizeTurn();
              }
            });
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _resultsSubscription?.close();
    _balancesSubscription?.close();
    super.dispose();
  }

  void _startCountdown() {
    // Guardamos el timer en la variable
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Si el widget ya no existe, cancelamos el timer y salimos
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() {
          _countdownFinished = true;
          _countdown = 0;
        });
      }
    });
  }

  // Callback que recibe la puntuación del minijuego hijo y la envía al backend.
  // Utiliza sendMinigameScore del WebSocketService.
  // Para Tren el backend exige también el campo 'objetivo' en el payload.
  void _onMinigameFinish(dynamic score) {
    final gameState = ref.read(gameProvider);

    // 1. INTERCEPTAMOS SI ES MODO DEBUG
    if (gameState.minigameDescription == "DEBUG_MODE") {
      debugPrint(
          " [DEBUG] Simulando resultados locales. Score enviado: $score");

      // Creamos un podio falso con los jugadores de la partida actual
      Map<String, dynamic> fakeResults = {};
      int pos = 1;
      for (var p in gameState.turnOrder) {
        // A ti te ponemos la puntuación real, a los demás puntuaciones inventadas
        // Si el score no es int (ej: es un string), no podemos hacer resta
        dynamic fakeScore;
        if (score is int) {
          fakeScore = pos == 1 ? score : score - (pos * 10);
        } else {
          fakeScore = score;
        }

        fakeResults[p] = {
          "posicion": pos,
          "score": fakeScore,
        };
        pos++;
      }

      // Enviamos los resultados al provider (como si vinieran del backend)
      // Interceptar si debug
      if (gameState.minigameDescription == "DEBUG_MODE") {
        debugPrint(
            " [DEBUG] Simulando resultados locales. Score enviado: $score");
        // ... (fakeResults) ...
        ref
            .read(gameProvider.notifier)
            .setMinigameResults(fakeResults, gameState.turnOrder);

        if (gameState.minigameName == 'Doble o Nada') {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              ref.read(gameProvider.notifier).finishMinigame();
              ref
                  .read(webSocketProvider)
                  .sendEndRound(); // Avisamos que terminamos la casilla
            }
          });
        }
        return;
      }
    }

    // Lógica normal (Si no es debug, se envía al backend)
    if (gameState.minigameName == 'Tren') {
      final objetivo =
          (gameState.minigameDetails?['objetivo'] as num?)?.toDouble();
      ref.read(webSocketProvider).sendMinigameScore(score, objetivo: objetivo);
    } else if (gameState.minigameName != 'Mano de Poker' &&
        gameState.minigameName != 'Poker' &&
        gameState.minigameName != 'Dilema del Prisionero') {
      ref.read(webSocketProvider).sendMinigameScore(score);
    }

    // Para Doble o Nada: guardamos la apuesta y esperamos al listener de balances
    // que detectará el resultado cuando llegue balances_changed del backend.
    if (gameState.minigameName == 'Doble o Nada') {
      setState(() => _apuestaDobleNada = score is int ? score : 0);
      return; // El listener _balancesSubscription se encarga del cierre
    }

    final isMinijuegoCasilla = gameState.minigameName == 'Mano de Poker' ||
        gameState.minigameName == 'Poker' ||
        gameState.minigameName == 'Dilema del Prisionero';

    if (isMinijuegoCasilla) {
      // Reducimos el delay drásticamente para Póker porque el usuario ya ha pulsado el botón "VOLVER" manualmente
      int delayMs = (gameState.minigameName == 'Mano de Poker' ||
              gameState.minigameName == 'Poker')
          ? 100
          : 2000;

      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
          final currentGameState = ref.read(gameProvider);
          final authUsername = ref.read(authProvider).username;

          final activePlayerId = currentGameState.activePlayerName;

          // Cierra el overlay para todos los participantes
          ref.read(gameProvider.notifier).finishMinigame();

          // Delegamos el avance y el end_round al evaluador maestro
          ref.read(webSocketProvider).checkAndFinalizeTurn();
        }
      });
    }
  }

  // Build principal — Máquina de estados visual

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);
    final results = gameState.minigameResults;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Minijuego (se dibuja ocupando todo el fondo por detrás del texto)
          if (_countdownFinished && results == null)
            Positioned.fill(
              child: MinigameFactory.buildGame(
                minigameName: gameState.minigameName ?? '',
                onFinish: _onMinigameFinish,
                details: gameState.minigameDetails ?? {},
              ),
            ),

          // 2. Elementos de UI superpuestos
          if (!_countdownFinished || results != null)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Header: Título y descripción (siempre visible) ──
                Text(
                  gameState.minigameName?.toUpperCase() ?? 'MINIJUEGO',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    shadows: [
                      Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(2, 2))
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (gameState.minigameDescription != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      gameState.minigameDescription!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                              color: Colors.black,
                              blurRadius: 4,
                              offset: Offset(1, 1))
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 48),

                // ── Contenido dinámico según el estado ──
                if (results != null)
                  // Estado 3: Han llegado los resultados → Mostrar podio
                  _buildResultsScreen(results)
                else if (!_countdownFinished)
                  // Estado 1: Cuenta atrás activa
                  _buildCountdownScreen(),
              ],
            ),
          // 3. Resultado de Doble o Nada (se superpone si ya tenemos el resultado)
          if (_dobleNadaGanado != null)
            _buildDobleNadaResult(_dobleNadaGanado!, _apuestaDobleNada ?? 0),
        ],
      ),
    );
  }

  // Widgets auxiliares

  // Pantalla de resultado de Doble o Nada
  Widget _buildDobleNadaResult(bool ganado, int apuesta) {
    final color = ganado ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final emoji = ganado ? '🎉' : '💸';
    final titulo = ganado ? '¡DOBLE O NADA!' : '¡MALA SUERTE!';
    final subtitulo = ganado
        ? 'Has ganado $apuesta monedas 🪙'
        : 'Has perdido $apuesta monedas 🪙';

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 30,
                  spreadRadius: 5),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                subtitulo,
                style: const TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Volviendo al tablero...',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 13,
                    fontFamily: 'Retro Gaming'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pantalla de cuenta atrás (3, 2, 1...)
  Widget _buildCountdownScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PREPÁRATE...',
          style: TextStyle(
            color: Colors.white70,
            fontFamily: 'Retro Gaming',
            fontSize: 20,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 30),
        Text(
          '$_countdown',
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Retro Gaming',
            fontSize: 100,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.amber, blurRadius: 20),
            ],
          ),
        ),
      ],
    );
  }

  // Pantalla de resultados (Podio) con cierre automático
  Widget _buildResultsScreen(Map<String, dynamic> results) {
    // Ordenar los resultados por posición
    final sortedEntries = results.entries.toList()
      ..sort((a, b) {
        final posA =
            (a.value as Map<String, dynamic>)['posicion'] as int? ?? 99;
        final posB =
            (b.value as Map<String, dynamic>)['posicion'] as int? ?? 99;
        return posA.compareTo(posB);
      });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '🏆 RESULTADOS',
          style: TextStyle(
            color: Colors.amber,
            fontFamily: 'Retro Gaming',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 400,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: sortedEntries.map((entry) {
              final data = entry.value as Map<String, dynamic>;
              final posicion = data['posicion'] as int? ?? 0;
              final score = data['score'];

              // Medalla según la posición
              String medal;
              switch (posicion) {
                case 1:
                  medal = '🥇';
                  break;
                case 2:
                  medal = '🥈';
                  break;
                case 3:
                  medal = '🥉';
                  break;
                default:
                  medal = '  ';
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(medal, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: posicion == 1 ? Colors.amber : Colors.white,
                          fontSize: 18,
                          fontWeight: posicion == 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '$score',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Volviendo al tablero...',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
        const SizedBox(height: 8),
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.amber,
            strokeWidth: 2,
          ),
        ),
      ],
    );
  }
}
