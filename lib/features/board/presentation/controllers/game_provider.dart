import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/gamemodels.dart';

// Declaración del provider global
final gameProvider = StateNotifierProvider<GameController, GameState>((ref) {
  return GameController();
});

// El controlador del juego
class GameController extends StateNotifier<GameState> {
  // Tamaño del tablero para esta prueba
  final int totalTiles = 20;

  // 3. Estado Inicial de la Partida
  GameController()
      : super(GameState(
          currentPhase: GamePhase.boardTurn,
          turnOrder: ['1', '2'], // El orden de los turnos (ID de los jugadores)
          activePlayerIndex:
              0, // Empieza el jugador en la posición 0 del turnOrder
          players: [
            Player(
              id: '1',
              username: 'Edu (Banquero) (Obviamente)',
              characterClass: CharacterClass.banquero,
              coins: 10,
              diceInventory: [DiceType.normal],
            ),
            Player(
              id: '2',
              username: 'Dani (Vidente)',
              characterClass: CharacterClass.vidente,
              coins: 10,
              diceInventory: [DiceType.normal],
            ),
          ],
          serverMessage: "¡Comienza el juego!",
        ));

  // Función para tirar los dados
  // TODO Cambiarla por una llamada a la api que tire los dados
  // El código siguiente es una simulación para ejecutarlo todo en local sin backend
  void rollDice() {
    // Los dados no se pueden tirar si la partida ha terminado
    if (state.currentPhase == GamePhase.finished) return;

    // Tirar el dado
    // Esta función se reemplazará con la llamada al backend
    // TODO Cambiar la función para llamar al backend
    final diceRoll = Random().nextInt(6) + 1;

    // Obtener el turno con el jugador que va a tirar AHORA
    final activePlayerId = state.turnOrder[state.activePlayerIndex];
    final currentPlayer =
        state.players.firstWhere((p) => p.id == activePlayerId);

    // Calcular a qué casilla se va a mover
    int newTileIndex = currentPlayer.currentTileIndex + diceRoll;

    // Si se pasa de la última casilla, se queda en la meta (Casilla 19)
    // En la versión final se harán más cosas (ir hacia atrás casillas)
    // TODO Cambiar la mecánica
    if (newTileIndex >= totalTiles - 1) {
      newTileIndex = totalTiles - 1;
    }

    // Actualizar la lista de jugadores con la nueva posición
    final updatedPlayers = state.players.map((p) {
      if (p.id == activePlayerId) {
        // copyWith crea un clon del jugador pero cambiándole SOLO la casilla
        return p.copyWith(currentTileIndex: newTileIndex);
      }
      return p; // Los demás jugadores se quedan igual
    }).toList();

    // Preparar qué jugador va a tirar después
    int nextPlayerIndex =
        (state.activePlayerIndex + 1) % state.turnOrder.length;

    // Comprobar si alguien ha ganado
    GamePhase nextPhase = state.currentPhase;
    String newMessage = "${currentPlayer.username} sacó un $diceRoll.";

    if (newTileIndex == totalTiles - 1) {
      nextPhase =
          GamePhase.finished; // Cambiamos la fase del juego a "Terminado"
      newMessage = "¡${currentPlayer.username} HA GANADO LA PARTIDA!";
    }

    // Emitir el nuevo estado a la UI
    // Al hacer esto, Riverpod avisa a board_screen.dart que debe redibujarse
    state = state.copyWith(
      players: updatedPlayers,
      lastDiceResult: diceRoll,
      activePlayerIndex: nextPlayerIndex,
      serverMessage: newMessage,
      currentPhase: nextPhase,
    );
  }
}
