// MinigameFactory — Selector dinámico de minijuegos
//
// Aquí se registra cada minijuego. Para añadir uno nuevo:
//   1. Importa el archivo del minijuego
//   2. Añade un 'case' con el nombre exacto que envía el backend
//

import 'package:flutter/material.dart';

// Importaciones de los minijuegos
import 'reflejos_game.dart';
import 'tren_game.dart';
import 'cronometro_game.dart';
import 'pan_game.dart';
import 'mayor_menor_game.dart';
import 'doble_nada_game.dart';

class MinigameFactory {
  /// Devuelve el widget del minijuego correspondiente al [minigameName].
  ///
  /// [onFinish] se pasa al minijuego para que avise cuando el jugador termine.
  /// [details] son los parámetros específicos que envía el backend.
  static Widget buildGame({
    required String minigameName,
    required Function(int score) onFinish,
    required Map<String, dynamic> details,
  }) {
    switch (minigameName) {
      case 'Reflejos':
        return ReflejosGame(onFinish: onFinish, details: details);
      case 'Tren':
        return TrenGame(onFinish: onFinish, details: details);
      case 'Cortar pan':
        return PanGame(onFinish: onFinish, details: details);
      case 'Cronometro ciego':
        return CronometroGame(onFinish: onFinish, details: details);
      case 'Mayor o Menor':
        return MayorMenorGame(onFinish: onFinish, details: details);
      case 'Doble o Nada':
        return DobleNadaGame(onFinish: onFinish, details: details);

      default:
        // Placeholder para minijuegos no implementados todavía
        return _buildPlaceholder(minigameName, onFinish);
    }
  }

  /// Widget de placeholder que simula un minijuego no implementado.
  /// Permite probar el flujo completo sin tener el juego real.
  static Widget _buildPlaceholder(
      String minigameName, Function(int score) onFinish) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction, size: 60, color: Colors.amber),
          const SizedBox(height: 16),
          Text(
            '"$minigameName"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Minijuego en construcción.\nPulsa el botón para simular una puntuación.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => onFinish(500), // Puntuación simulada
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Simular Fin',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
