// ============================================================
// MinigameOverlay — Contenedor genérico para todos los minijuegos
// ============================================================
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
  // ============================================================
  // Estado interno del overlay
  // ============================================================

  int _countdown = 3;
  bool _countdownFinished = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  // Cuenta atrás de 3 segundos antes de mostrar el minijuego
  void _startCountdown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
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

  // Callback que recibe la puntuación del minijuego hijo y la envía al backend
  void _onMinigameFinish(int score) {
    ref.read(webSocketProvider).sendMinigameScore(score);
  }

  // ============================================================
  // Build principal — Máquina de estados visual
  // ============================================================

  @override
  Widget build(BuildContext context) {
    // Escuchar cambios en los resultados para disparar el cierre automático una sola vez
    ref.listen(gameProvider.select((s) => s.minigameResults), (prev, next) {
      if (prev == null && next != null) {
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && ref.read(gameProvider).minigameResults != null) {
            ref.read(gameProvider.notifier).finishMinigame();
          }
        });
      }
    });

    final gameState = ref.watch(gameProvider);
    final results = gameState.minigameResults;

    return Container(
      color: Colors.black.withOpacity(0.85),
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
                  shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))],
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
                      shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
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

  // ============================================================
  // Widgets auxiliares
  // ============================================================

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
        final posA = (a.value as Map<String, dynamic>)['posicion'] as int? ?? 99;
        final posB = (b.value as Map<String, dynamic>)['posicion'] as int? ?? 99;
        return posA.compareTo(posB);
      });

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '🏆 RESULTADOS',
          style: TextStyle(
              color: Colors.amber,
              fontSize: 28,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Container(
          width: 400,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
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
