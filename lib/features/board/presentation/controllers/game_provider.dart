import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/gamemodels.dart';

// Declaración del provider global
final gameProvider = StateNotifierProvider<GameController, GameState>((ref) {
  return GameController();
});

// El controlador del juego
class GameController extends StateNotifier<GameState> {
  // Tamaño del tablero para esta prueba (73 casillas según las coordenadas definidas)
  final int totalTiles = 73;

  // 3. Estado Inicial de la Partida — 4 jugadores según el diseño del tablero
  GameController()
      : super(GameState(
          currentPhase: GamePhase.boardTurn,
          turnOrder: ['1', '2', '3', '4'],
          activePlayerIndex: 0,
          players: [
            Player(
              id: '1',
              username: 'David',
              characterClass: CharacterClass.videojugador,
              coins: 0,
              diceInventory: [DiceType.normal],
            ),
            Player(
              id: '2',
              username: 'Elena',
              characterClass: CharacterClass.banquero,
              coins: 0,
              diceInventory: [DiceType.normal],
            ),
            Player(
              id: '3',
              username: 'Marcos',
              characterClass: CharacterClass.escapista,
              coins: 0,
              diceInventory: [DiceType.normal],
            ),
            Player(
              id: '4',
              username: 'Lucía',
              characterClass: CharacterClass.vidente,
              coins: 0,
              diceInventory: [DiceType.normal],
            ),
          ],
          serverMessage: "¡Comienza el juego!",
        ));

  // Función para tirar los dados
  void rollDice() async {
    if (state.currentPhase == GamePhase.finished) return;

    final diceRoll = Random().nextInt(6) + 1;

    final activePlayerId = state.turnOrder[state.activePlayerIndex];
    final currentPlayer =
        state.players.firstWhere((p) => p.id == activePlayerId);

    int targetTileIndex = currentPlayer.currentTileIndex + diceRoll;

    if (targetTileIndex >= totalTiles - 1) {
      targetTileIndex = totalTiles - 1;
    }

    String newMessage = "${currentPlayer.username} sacó un $diceRoll.";

    // Animación de movimiento paso a paso
    for (int i = currentPlayer.currentTileIndex + 1; i <= targetTileIndex; i++) {
      await Future.delayed(const Duration(milliseconds: 350));
      
      final stepPlayers = state.players.map((p) {
        if (p.id == activePlayerId) {
          return p.copyWith(currentTileIndex: i);
        }
        return p;
      }).toList();

      state = state.copyWith(
        players: stepPlayers, 
        serverMessage: newMessage, 
        lastDiceResult: diceRoll
      );
    }

    int nextPlayerIndex =
        (state.activePlayerIndex + 1) % state.turnOrder.length;

    GamePhase nextPhase = state.currentPhase;

    if (targetTileIndex == totalTiles - 1) {
      nextPhase = GamePhase.finished;
      newMessage = "¡${currentPlayer.username} HA GANADO LA PARTIDA!";
    }

    state = state.copyWith(
      activePlayerIndex: nextPlayerIndex,
      serverMessage: newMessage,
      currentPhase: nextPhase,
    );
  }

  // Método para recibir datos del backend sobre el movimiento de un jugador
  void updatePlayerFromBackend(
      String playerId, int newTileIndex, int diceRoll) async {
    if (state.currentPhase == GamePhase.finished) return;

    final currentPlayer = state.players.firstWhere((p) => p.id == playerId);

    String newMessage = "${currentPlayer.username} sacó un $diceRoll.";

    // Animación de movimiento paso a paso
    for (int i = currentPlayer.currentTileIndex + 1; i <= newTileIndex; i++) {
      await Future.delayed(const Duration(milliseconds: 350));
      
      final stepPlayers = state.players.map((p) {
        if (p.id == playerId) {
          return p.copyWith(currentTileIndex: i);
        }
        return p;
      }).toList();

      state = state.copyWith(
        players: stepPlayers, 
        serverMessage: newMessage, 
        lastDiceResult: diceRoll
      );
    }

    GamePhase nextPhase = state.currentPhase;

    if (newTileIndex >= totalTiles - 1) {
      nextPhase = GamePhase.finished;
      newMessage = "¡${currentPlayer.username} HA GANADO LA PARTIDA!";
    }

    int nextPlayerIndex =
        (state.activePlayerIndex + 1) % state.turnOrder.length;

    state = state.copyWith(
      activePlayerIndex: nextPlayerIndex,
      serverMessage: newMessage,
      currentPhase: nextPhase,
    );
  }
}
