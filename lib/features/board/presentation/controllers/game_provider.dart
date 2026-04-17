import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/gamemodels.dart';
import 'dart:async';

// Declaración del provider global
final gameProvider = StateNotifierProvider<GameController, GameState>((ref) {
  return GameController();
});

// El controlador del juego
class GameController extends StateNotifier<GameState> {
  // Tamaño del tablero para esta prueba (73 casillas según las coordenadas definidas)
  final int totalTiles = 73;

  // Para manejar animaciones secuenciales de movimiento
  final List<Future<void> Function()> _animationQueue = [];
  bool _isAnimating = false;
  bool get isAnimationQueueEmpty => _animationQueue.isEmpty && !_isAnimating;

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

  Future<void> updatePlayerFromBackend(
      String playerId, int newTileIndex, int diceRoll,
      {int dice1 = 0, int dice2 = 0}) async {
    final completer = Completer<void>();

    _animationQueue.add(() async {
      await _performUpdatePlayer(playerId, newTileIndex, diceRoll,
          dice1: dice1, dice2: dice2);
      completer.complete();
    });

    _processQueue();
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_isAnimating || _animationQueue.isEmpty) return;
    _isAnimating = true;

    while (_animationQueue.isNotEmpty) {
      final task = _animationQueue.removeAt(0);
      await task();
    }

    _isAnimating = false;
  }

  // Método para recibir datos del backend sobre el movimiento de un jugador
  Future<void> _performUpdatePlayer(
      String playerId, int newTileIndex, int diceRoll,
      {int dice1 = 0, int dice2 = 0}) async {
    if (state.currentPhase == GamePhase.finished) return;

    // Solo bloqueamos y esperamos 2 segundos si es una tirada manual (diceRoll > 0)
    if (diceRoll > 0) {
      state = state.copyWith(
        isMovementActive: true,
        lastDiceResult: diceRoll,
        lastDice1: dice1,
        lastDice2: dice2,
        lastDiceRollId: state.lastDiceRollId + 1,
        serverMessage:
            "${state.players.firstWhere((p) => p.id == playerId).username} sacó un $diceRoll.",
      );
      // ESPERA de 2 segundos para que se vea el resultado del dado ANTES de mover
      await Future.delayed(const Duration(seconds: 2));
    } else {
      // Movimiento automático (salto extra, penalización, etc.)
      state = state.copyWith(
        isMovementActive: true,
        serverMessage:
            "${state.players.firstWhere((p) => p.id == playerId).username} se desplaza por el tablero.",
      );
      // ESPERA de 400ms para casillas de movimiento automático
      await Future.delayed(const Duration(milliseconds: 400));
    }

    final currentPlayer = state.players.firstWhere((p) => p.id == playerId);

    // DEBUG DETALLADO
    debugPrint(' ACTUALIZANDO JUGADOR:');
    debugPrint('  Jugador: ${currentPlayer.username} (ID: $playerId)');
    debugPrint('  Posición ACTUAL: ${currentPlayer.currentTileIndex}');
    debugPrint('  Dado tirado: $diceRoll');
    debugPrint('  Nueva casilla (del backend): $newTileIndex');
    debugPrint(
        '  Diferencia: ${newTileIndex - currentPlayer.currentTileIndex}');
    debugPrint(
        '  ¿Coincide dado con diferencia?: ${diceRoll == (newTileIndex - currentPlayer.currentTileIndex)}');
    debugPrint('  Total jugadores: ${state.players.length}');
    debugPrint('  Turno order: ${state.turnOrder}');
    debugPrint('  Active player index actual: ${state.activePlayerIndex}');
    debugPrint(
        '  Próximo index: ${(state.activePlayerIndex + 1) % state.turnOrder.length}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Mensaje según si es movimiento o corrección
    String newMessage = diceRoll == 0
        ? "${currentPlayer.username} ajusta su posición."
        : "${currentPlayer.username} sacó un $diceRoll.";

    // Animación de movimiento paso a paso (funciona tanto para avance como retroceso)
    final startPos = currentPlayer.currentTileIndex;

    // Nos aseguramos de que el nuevo índice no supere el máximo del tablero
    final endPos =
        newTileIndex >= totalTiles - 1 ? totalTiles - 1 : newTileIndex;
    final isMovingForward = endPos > startPos;

    if (isMovingForward) {
      // Avance: 5 → 9 (5, 6, 7, 8, 9)
      for (int i = startPos + 1; i <= endPos; i++) {
        final stepPlayers = state.players.map((p) {
          if (p.id == playerId) {
            return p.copyWith(currentTileIndex: i);
          }
          return p;
        }).toList();

        state = state.copyWith(
            players: stepPlayers,
            serverMessage: newMessage,
            lastDiceResult: diceRoll == 0 ? state.lastDiceResult : diceRoll,
            lastDice1: diceRoll == 0 ? state.lastDice1 : dice1,
            lastDice2: diceRoll == 0 ? state.lastDice2 : dice2);

        await Future.delayed(const Duration(milliseconds: 280));
      }
    } else {
      // Retroceso: 9 → 5 (9, 8, 7, 6, 5)
      for (int i = startPos - 1; i >= endPos; i--) {
        final stepPlayers = state.players.map((p) {
          if (p.id == playerId) {
            return p.copyWith(currentTileIndex: i);
          }
          return p;
        }).toList();

        state = state.copyWith(
            players: stepPlayers,
            serverMessage: newMessage,
            lastDiceResult: diceRoll == 0 ? state.lastDiceResult : diceRoll,
            lastDice1: diceRoll == 0 ? state.lastDice1 : dice1,
            lastDice2: diceRoll == 0 ? state.lastDice2 : dice2);

        await Future.delayed(const Duration(milliseconds: 280));
      }
    }

    // AL FINAL DE LA ANIMACIÓN
    // Leemos la fase en tiempo real porque pudo haber llegado un ini_minijuego mientras tanto
    GamePhase finalPhase = state.currentPhase;

    if (newTileIndex >= totalTiles - 1) {
      finalPhase = GamePhase.finished;
      newMessage = "¡${currentPlayer.username} HA GANADO LA PARTIDA!";
    }

    if (diceRoll != 0) {
      int nextPlayerIndex =
          (state.activePlayerIndex + 1) % state.turnOrder.length;
      int nextRound = state.currentRound;

      if (nextPlayerIndex == 0) {
        nextRound += 1;
      }

      state = state.copyWith(
        activePlayerIndex: nextPlayerIndex,
        currentRound: nextRound,
        serverMessage: newMessage,
        currentPhase: finalPhase, // Usamos la fase final real
        isMovementActive: false, // Desbloqueo al final del turno
      );
    } else {
      state = state.copyWith(
        serverMessage: newMessage,
        currentPhase: finalPhase, // Usamos la fase final real
        isMovementActive: false, // FIN de movimiento y desbloqueo
      );
    }
  }

  // Método para sincronizar el estado completo desde el backend en una reconexión
  void syncBoardState(Map<String, dynamic> boardState, String gameStatus) {
    // Si la partida está jugandose en el servidor, actualizamos la fase
    GamePhase newPhase =
        gameStatus == "PLAYING" ? GamePhase.boardTurn : state.currentPhase;

    final positions = boardState['positions'] as Map<String, dynamic>? ?? {};
    final balances = boardState['balances'] as Map<String, dynamic>? ?? {};
    final characters = boardState['characters'] as Map<String, dynamic>? ?? {};
    final order = boardState['order'] as Map<String, dynamic>? ?? {};
    final penaltyTurns =
        boardState['penalty_turns'] as Map<String, dynamic>? ?? {};

    debugPrint('═══════════════════════════════════════════');
    debugPrint(' SYNC BOARD STATE - Datos del backend:');
    debugPrint('  • Número de jugadores: ${positions.length}');
    debugPrint('  • Posiciones: $positions');
    debugPrint('  • Orden: $order');
    debugPrint('  • Caracteres: $characters');
    debugPrint('  • Balances: $balances');
    debugPrint('═══════════════════════════════════════════');

    // Reconstruimos la lista de jugadores basándonos en los datos del backend
    List<Player> updatedPlayers = [];
    List<String> newTurnOrder = List.filled(positions.length, '');

    positions.forEach((username, pos) {
      final String id =
          username; // El backend ahora mismo usa el nombre como ID/key

      final playerOrder = (order[username] as int?) ?? 1;

      // Intentamos mantener los datos que ya teníamos si existen
      Player existingPlayer = state.players.firstWhere(
        (p) => p.id == id,
        orElse: () => Player(
          id: id,
          username: username,
          characterClass:
              CharacterClass.banquero, // Default si no se ha elegido
        ),
      );

      // Convertimos el string del character a nuestro Enum
      CharacterClass charClass = existingPlayer.characterClass;
      if (characters.containsKey(username)) {
        final charString = characters[username].toString().toLowerCase();
        if (charString.contains('escapista')) {
          charClass = CharacterClass.escapista;
        } else if (charString.contains('vidente')) {
          charClass = CharacterClass.vidente;
        } else if (charString.contains('videojugador')) {
          charClass = CharacterClass.videojugador;
        } else {
          charClass = CharacterClass.banquero;
        }
      }

      updatedPlayers.add(existingPlayer.copyWith(
        currentTileIndex: pos as int,
        coins: balances[username] as int? ?? 0,
        characterClass: charClass,
        penaltyTurns: penaltyTurns[username] as int? ?? 0,
      ));

      // Guardar el orden de turno (el backend da base 1, array base 0)
      if (playerOrder > 0 && playerOrder <= newTurnOrder.length) {
        newTurnOrder[playerOrder - 1] = id;
      }
    });

    // Filtramos vacíos por si alguien falta en el order (ej: test con 1 player)
    final cleanTurnOrder = newTurnOrder.where((id) => id.isNotEmpty).toList();

    debugPrint('✅ Jugadores cargados del backend:');
    for (var p in updatedPlayers) {
      debugPrint(
          '  • ${p.username} (ID: ${p.id}) - Casilla ${p.currentTileIndex} - ${p.characterClass.name}');
    }
    debugPrint('  Turno order: $cleanTurnOrder');
    debugPrint('═══════════════════════════════════════════');

    state = state.copyWith(
      currentPhase: newPhase,
      players: updatedPlayers.isNotEmpty ? updatedPlayers : state.players,
      turnOrder: cleanTurnOrder.isNotEmpty ? cleanTurnOrder : state.turnOrder,
      serverMessage: "Sincronizado con el servidor",
    );
  }

  // Minijuegos

  void startMinigame({
    required String name,
    String? description,
    Map<String, dynamic>? details,
  }) {
    // Usamos el constructor directamente porque copyWith no puede poner
    // campos nullable a null (null ?? valorAnterior = valorAnterior).
    // Si llamamos copyWith(minigameResults: null), el ?? devuelve el
    // resultado de la ronda anterior y la pantalla de resultados persiste.
    state = GameState(
      currentPhase: GamePhase.minigameOrder,
      currentRound: state.currentRound,
      players: state.players,
      turnOrder: state.turnOrder,
      activePlayerIndex: state.activePlayerIndex,
      serverMessage: state.serverMessage,
      minigameName: name,
      minigameDescription: description,
      minigameDetails: details,
      // minigameResults: null (por defecto) — reset intencional
      // minigameChoices: null (por defecto)
      isWaitingForMinigameChoice: false,
    );
  }

  void setMinigameResults(Map<String, dynamic> results, List<String> newOrder) {
    state = state.copyWith(
      minigameResults: results,
      turnOrder: newOrder,
    );
  }

  void finishMinigame() {
    // Igual que startMinigame: construimos el estado directamente para
    // poder poner todos los campos de minijuego a null de verdad.
    state = GameState(
      currentPhase: GamePhase.boardTurn,
      currentRound: state.currentRound,
      players: state.players,
      turnOrder: state.turnOrder,
      activePlayerIndex: state.activePlayerIndex,
      serverMessage: state.serverMessage,
      // minigameName, Description, Details, Results, Choices: null por defecto
      isWaitingForMinigameChoice: false,
    );
  }

  // Método para actualizar monedas e inventario
  void updateInventoryAndBalance(String playerId,
      {List<ItemType>? newInventory, int? newBalance}) {
    final updatedPlayers = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(
          itemInventory: newInventory ?? p.itemInventory,
          coins: newBalance ?? p.coins,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(players: updatedPlayers);
  }

  void setMinigameChoices(List<String> choices) {
    state = state.copyWith(minigameChoices: choices);
  }

  void clearMinigameChoices() {
    state = state.copyWith(minigameChoices: []);
  }

  void setWaitingForMinigameChoice(bool waiting) {
    state = state.copyWith(isWaitingForMinigameChoice: waiting);
  }

  void showObtainedItem(String name, String desc) {
    state = state.copyWith(obtainedItemName: name, obtainedItemDesc: desc);
  }

  void hideObtainedItem() {
    state = GameState(
      // Truco similar a finishMinigame para forzar a null
      currentPhase: state.currentPhase, currentRound: state.currentRound,
      players: state.players, turnOrder: state.turnOrder,
      activePlayerIndex: state.activePlayerIndex,
      serverMessage: state.serverMessage,
      isWaitingForMinigameChoice: state.isWaitingForMinigameChoice,
    );
  }

  void updatePenalty(String playerId, int turns) {
    final updated = state.players
        .map((p) => p.id == playerId ? p.copyWith(penaltyTurns: turns) : p)
        .toList();
    state = state.copyWith(players: updated);
  }

  // MODO DEBUG: Inicia un minijuego localmente sin avisar al backend
  void startDebugMinigameLocal(String name) {
    Map<String, dynamic> mockDetails = {};

    // Generamos datos falsos según lo que necesite cada minijuego
    if (name == 'Tren') {
      mockDetails = {'objetivo': 20.0};
    } else if (name == 'Mayor o Menor') {
      mockDetails = {
        'cartas': [12, 25, 38, 51],
        'personaje': 'banquero'
      };
    } else if (name == 'Cronometro ciego') {
      mockDetails = {'objetivo': 8};
    } else if (name == 'Cortar pan') {
      mockDetails = {'objetivo': 50};
    }

    startMinigame(
      name: name,
      description: "DEBUG_MODE", // Usamos esto como bandera secreta
      details: mockDetails,
    );
  }
}
