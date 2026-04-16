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
            // El cierre automático ocurre 5 s despues de mostrar los resultados
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && ref.read(gameProvider).minigameResults != null) {
                ref.read(gameProvider.notifier).finishMinigame();
              }
            });
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel(); // <-- AÑADE ESTO PARA CANCELAR EL TIMER
    _resultsSubscription?.close();
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
  void _onMinigameFinish(int score) {
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
        fakeResults[p] = {
          "posicion": pos,
          "score": pos == 1 ? score : score - (pos * 10)
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
      final objetivo = gameState.minigameDetails?['objetivo'] as double?;
      ref.read(webSocketProvider).sendMinigameScore(score, objetivo: objetivo);
    } else {
      ref.read(webSocketProvider).sendMinigameScore(score);
    }

    if (gameState.minigameName == 'Doble o Nada') {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          ref.read(gameProvider.notifier).finishMinigame();
          // Avisa al backend para pasar el turno
          ref.read(webSocketProvider).sendEndRound();
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
        ],
      ),
    );
  }

  // Widgets auxiliares

  // Pantalla de cuenta atrás (3, 2, 1...)
  Widget _buildCountdownScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'PREPÁRATE...',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        const SizedBox(height: 20),
        Text(
          '$_countdown',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 80,
            fontWeight: FontWeight.bold,
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
              color: Colors.amber, fontSize: 28, fontWeight: FontWeight.bold),
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
