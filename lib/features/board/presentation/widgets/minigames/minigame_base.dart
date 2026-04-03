// ============================================================
// MinigameBase — Interfaz abstracta para todos los minijuegos
// ============================================================
//
// Para crear un nuevo minijuego:
//   1. Crea un archivo en esta misma carpeta (ej: reflejos_game.dart)
//   2. Tu widget debe implementar MinigameBase
//   3. Cuando el jugador termine, llama a onFinish(puntuacion)
//   4. Registra tu juego en minigame_factory.dart
//

import 'package:flutter/material.dart';

/// Interfaz que todo widget de minijuego debe cumplir.
///
/// [onFinish] — Callback que el minijuego invoca al terminar,
///              pasando la puntuación obtenida como int.
/// [details]  — Mapa con los parámetros enviados por el backend
///              (ej: {"objetivo": 10} para Tren, {"cartas": [3,15,27]} para Mayor o Menor).
abstract class MinigameBase extends StatefulWidget {
  final Function(int score) onFinish;
  final Map<String, dynamic> details;

  const MinigameBase({
    super.key,
    required this.onFinish,
    required this.details,
  });
}
