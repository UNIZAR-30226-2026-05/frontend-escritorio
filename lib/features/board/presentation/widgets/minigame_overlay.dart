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
            final isDobleNada = ref.read(gameProvider).minigameName == 'Doble o Nada';
            final delay = isDobleNada ? 4 : 5;
            
            // El cierre automático ocurre después de mostrar los resultados
            Future.delayed(Duration(seconds: delay), () {
              if (mounted && ref.read(gameProvider).minigameResults != null) {
                ref.read(gameProvider.notifier).finishMinigame();
                if (isDobleNada) {
                  ref.read(webSocketProvider).checkAndFinalizeTurn();
                }
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
    super.dispose();
  }

  void _startCountdown() {
    final gameState = ref.read(gameProvider);
    final myUsername = ref.read(authProvider).username;
    
    // Si somos espectadores en Doble o Nada, saltamos el countdown para que
    // aparezca inmediatamente la pantalla de espera sin el título de "MINIJUEGO"
    if (gameState.minigameName == 'Doble o Nada' && gameState.activePlayerName != myUsername) {
      setState(() {
        _countdownFinished = true;
        _countdown = 0;
      });
      return;
    }

    // Igual para espectadores del Dilema del Prisionero (no participantes)
    if (gameState.minigameName == 'Dilema del Prisionero') {
      final participants = (gameState.minigameDetails?['jugadores'] as List?)?.cast<String>() ?? [];
      if (!participants.contains(myUsername)) {
        setState(() {
          _countdownFinished = true;
          _countdown = 0;
        });
        return;
      }
    }

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
        gameState.minigameName != 'Poker') {
      // Dilema del Prisionero también envía aquí su voto ('cooperar'/'traicionar').
      // El overlay NO se cierra hasta recibir minijuego_resultados (ver _resultsSubscription).
      ref.read(webSocketProvider).sendMinigameScore(score);
    }

    // Doble o Nada también espera a doblenada_resultados del backend
    if (gameState.minigameName == 'Doble o Nada') {
      return; 
    }

    // Dilema del Prisionero espera minijuego_resultados igual que los minijuegos
    // de orden; _resultsSubscription ya maneja el cierre automático.
    final isMinijuegoCasilla = gameState.minigameName == 'Mano de Poker' ||
        gameState.minigameName == 'Poker';

    if (isMinijuegoCasilla) {
      // Reducimos el delay drásticamente para Póker porque el usuario ya ha pulsado el botón "VOLVER" manualmente
      int delayMs = (gameState.minigameName == 'Mano de Poker' ||
              gameState.minigameName == 'Poker')
          ? 100
          : 2000;

      Future.delayed(Duration(milliseconds: delayMs), () {
        if (mounted) {
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
            if (gameState.minigameName == 'Doble o Nada' && gameState.activePlayerName != ref.read(authProvider).username)
              _buildDobleNadaWaitingScreen(gameState.activePlayerName ?? '')
            else if (gameState.minigameName == 'Dilema del Prisionero') ...((){
              final myUser = ref.read(authProvider).username ?? '';
              final participants = (gameState.minigameDetails?['jugadores'] as List?)?.cast<String>() ?? [];
              if (!participants.contains(myUser)) {
                return [_buildDilemaWaitingScreen(gameState.activePlayerName ?? '')];
              }
              return [Positioned.fill(
                child: MinigameFactory.buildGame(
                  minigameName: gameState.minigameName ?? '',
                  onFinish: _onMinigameFinish,
                  details: gameState.minigameDetails ?? {},
                ),
              )];
            })()
            else
              Positioned.fill(
                child: MinigameFactory.buildGame(
                  minigameName: gameState.minigameName ?? '',
                  onFinish: _onMinigameFinish,
                  details: gameState.minigameDetails ?? {},
                ),
              ),

          // 2. Elementos de UI superpuestos
          if (!_countdownFinished || (results != null && gameState.minigameName != 'Doble o Nada'))
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
          
          // 3. Resultado específico de Doble o Nada
          if (results != null && gameState.minigameName == 'Doble o Nada')
            _buildDobleNadaResult(results, gameState.activePlayerName ?? '', ref.read(authProvider).username ?? ''),
        ],
      ),
    );
  }

  // Widgets auxiliares

  Widget _buildDobleNadaWaitingScreen(String activePlayer) {
    return Center(
      child: Container(
        width: 500,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1B38),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DOBLE O NADA',
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Text(
                  '${activePlayer.toUpperCase()} ESTÁ\nDESAFIANDO A LA\nSUERTE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: 20,
                    color: Colors.amber,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'ESPERANDO RESULTADO...',
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildDilemaWaitingScreen(String activePlayer) {
    return Center(
      child: Container(
        width: 500,
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2538),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.purpleAccent, width: 4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DILEMA DEL PRISIONERO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Text(
                '${activePlayer.toUpperCase()} ESTÁ\nCOOPERANDO O\nTRAICIONANDO',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 20,
                  color: Colors.purpleAccent,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'ESPERANDO DECISIÓN...',
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pantalla de resultado de Doble o Nada
  Widget _buildDobleNadaResult(Map<String, dynamic> results, String activePlayer, String myUsername) {
    final bool isMyTurn = activePlayer == myUsername;
    final data = results[activePlayer] as Map<String, dynamic>? ?? {};
    final bool ganado = data['ganado'] == true;
    final int apuesta = data['apuesta'] ?? 0;

    final color = ganado ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final String titleText;
    if (isMyTurn) {
      titleText = ganado ? 'HAS GANADO' : 'HAS PERDIDO';
    } else {
      titleText = ganado ? '${activePlayer.toUpperCase()} HA\nGANADO' : '${activePlayer.toUpperCase()} HA\nPERDIDO';
    }

    return Center(
      child: Container(
        width: 500,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A1B38),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DOBLE O NADA',
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Retro Gaming',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'APUESTA: $apuesta¢',
                      style: const TextStyle(
                        fontFamily: 'Retro Gaming',
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ganado ? '+$apuesta¢' : '-$apuesta¢',
                      style: const TextStyle(
                        fontFamily: 'Retro Gaming',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'CERRANDO RONDA EN BREVE...',
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
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
