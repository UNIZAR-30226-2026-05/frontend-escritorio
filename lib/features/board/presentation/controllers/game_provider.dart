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
  // Tamaño del tablero para esta prueba (72 casillas, la meta es la 71)
  final int totalTiles = 72;

  // Para manejar animaciones secuenciales de movimiento
  final List<Future<void> Function()> _animationQueue = [];
  bool _isAnimating = false;
  Completer<void>? _rouletteCompleter;
  bool get isAnimationQueueEmpty => _animationQueue.isEmpty && !_isAnimating;

  // Estado Inicial de la Partida
  GameController()
      : super(GameState(
          currentPhase: GamePhase.boardTurn,
          turnOrder: ['1', '2', '3', '4'],
          activePlayerName: 'David',
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

    try {
      while (_animationQueue.isNotEmpty) {
        final task = _animationQueue.removeAt(0);
        await task();
      }
    } finally {
      _isAnimating = false;
    }
  }

  void enqueueTask(Future<void> Function() task) {
    _animationQueue.add(task);
    _processQueue();
  }

  // Método para recibir datos del backend sobre el movimiento de un jugador
  Future<void> _performUpdatePlayer(
      String playerId, int newTileIndex, int diceRoll,
      {int dice1 = 0, int dice2 = 0}) async {
    if (state.currentPhase == GamePhase.finished) return;

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
      await Future.delayed(const Duration(seconds: 2));
    } else {
      state = state.copyWith(
        isMovementActive: true,
        serverMessage:
            "${state.players.firstWhere((p) => p.id == playerId).username} se desplaza por el tablero.",
      );
      await Future.delayed(const Duration(milliseconds: 400));
    }

    final currentPlayer = state.players.firstWhere((p) => p.id == playerId);
    String newMessage = diceRoll == 0
        ? "${currentPlayer.username} ajusta su posición."
        : "${currentPlayer.username} sacó un $diceRoll.";

    final startPos = currentPlayer.currentTileIndex;
    final endPos =
        newTileIndex >= totalTiles - 1 ? totalTiles - 1 : newTileIndex;
    final isMovingForward = endPos > startPos;

    if (isMovingForward) {
      for (int i = startPos + 1; i <= endPos; i++) {
        final stepPlayers = state.players
            .map((p) => p.id == playerId ? p.copyWith(currentTileIndex: i) : p)
            .toList();
        state = state.copyWith(players: stepPlayers, serverMessage: newMessage);
        await Future.delayed(const Duration(milliseconds: 280));
      }
    } else {
      for (int i = startPos - 1; i >= endPos; i--) {
        final stepPlayers = state.players
            .map((p) => p.id == playerId ? p.copyWith(currentTileIndex: i) : p)
            .toList();
        state = state.copyWith(players: stepPlayers, serverMessage: newMessage);
        await Future.delayed(const Duration(milliseconds: 280));
      }
    }

    GamePhase finalPhase = state.currentPhase;
    String? newWinner = state.winnerName;

    if (newTileIndex >= totalTiles - 1) {
      finalPhase = GamePhase.finished;
      newMessage = "¡${currentPlayer.username} HA GANADO LA PARTIDA!";
      newWinner = currentPlayer.username;
    }

    // Ya NO avanzamos el turno aquí. Lo dejamos en manos del checkAndFinalizeTurn
    state = state.copyWith(
      serverMessage: newMessage,
      currentPhase: finalPhase,
      isMovementActive: false,
      winnerName: newWinner,
    );
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

    // Buscamos de quién es el turno
    final int turnoActual =
        boardState['turn'] ?? boardState['turno_actual'] ?? 1;
    String? activeName;
    order.forEach((key, value) {
      if (value == turnoActual) activeName = key;
    });

    debugPrint('  • Turno actual (backend): $turnoActual');
    debugPrint('  • Jugador activo identificado: $activeName');

    state = state.copyWith(
      currentPhase: newPhase,
      players: updatedPlayers.isNotEmpty ? updatedPlayers : state.players,
      turnOrder: cleanTurnOrder.isNotEmpty ? cleanTurnOrder : state.turnOrder,
      activePlayerName: activeName,
      serverMessage: "Sincronizado con el servidor",
      lastDiceResult: null, // Limpiar tiradas viejas al sincronizar
      isMovementActive: false, // Asegurar tablero estático tras sincro
    );
  }

  // Minijuegos

  void startMinigame({
    required String name,
    String? description,
    Map<String, dynamic>? details,
  }) {
    // Mapeo de descripciones únicas para cada minijuego (evita mensajes genéricos)
    final Map<String, String> customDescriptions = {
      'Reflejos': '¡Pulsa al ver la señal!',
      'Tren': 'Cuenta cuántos osos hay en el tren',
      'Cortar pan': '¡Corta el pan con precisión!',
      'Cronometro ciego': 'Para el tiempo en el segundo exacto',
      'Mayor o Menor': 'Adivina la próxima carta',
      'Doble o Nada': 'Arriésgate a doblar tus monedas',
      'Dilema del Prisionero': '¿Colaborar o traicionar? Tú decides',
    };

    final finalDesc = customDescriptions[name] ?? description;

    // Identificamos si es un minijuego de casilla para no bloquear el tablero global
    final isTileMinigame = name == 'Mano de Poker' ||
        name == 'Poker' ||
        name == 'Dilema del Prisionero' ||
        name == 'Doble o Nada';

    state = GameState(
      currentPhase:
          isTileMinigame ? GamePhase.minigameTile : GamePhase.minigameOrder,
      currentRound: state.currentRound,
      players: state.players,
      turnOrder: state.turnOrder,
      activePlayerName: state.activePlayerName,
      serverMessage: state.serverMessage,
      minigameName: name,
      minigameDescription: finalDesc,
      minigameDetails: (details == null || details.isEmpty)
          ? state.minigameDetails
          : details,
      // minigameResults: null (por defecto), reset intencional
      // minigameChoices: null (por defecto)
      isWaitingForMinigameChoice: false,
      winnerName: state.winnerName,
    );
  }

  void setMinigameResults(Map<String, dynamic> results, List<String> newOrder) {
    state = state.copyWith(
      minigameResults: results,
      turnOrder: newOrder,
    );
  }

  // Actualiza la lista de items comprados en el turno
  void addTurnPurchasedItem(String itemName) {
    final currentItems = Map<String, int>.from(state.turnPurchasedItems);
    currentItems[itemName] = (currentItems[itemName] ?? 0) + 1;
    state = state.copyWith(turnPurchasedItems: currentItems);
  }

  void clearTurnPurchasedItems() {
    state = state.copyWith(
      turnPurchasedItems: {},
      clearTheftMessage: true,
    );
  }

  void setTurnTheftMessage(String message) {
    state = state.copyWith(turnTheftMessage: message);
  }

  void clearTurnTheftMessage() {
    state = state.copyWith(clearTheftMessage: true);
  }

  // Actualiza los detalles del minijuego actual fusionando los nuevos datos.
  // Útil para minijuegos con múltiples fases como el Póker.
  void updateMinigameDetails(Map<String, dynamic> newDetails) {
    final type = newDetails['type'];
    final isNewGame =
        type == 'minijuego_casilla' || type == 'poker_inicio_ronda';

    final currentDetails =
        isNewGame ? <String, dynamic>{} : (state.minigameDetails ?? {});
    final merged = {...currentDetails, ...newDetails};
    state = state.copyWith(minigameDetails: merged);
  }

  void finishMinigame() {
    // Igual que startMinigame: construimos el estado directamente para
    // poder poner todos los campos de minijuego a null de verdad.
    state = GameState(
      currentPhase: GamePhase.boardTurn,
      currentRound: state.currentRound,
      players: state.players,
      turnOrder: state.turnOrder,
      activePlayerName: state.activePlayerName,
      serverMessage: state.serverMessage,
      isWaitingForMinigameChoice: state.isWaitingForMinigameChoice,
      minigameChoices: state.minigameChoices,
      winnerName: state.winnerName,
      lastDiceResult: state.lastDiceResult,
      lastDice1: state.lastDice1,
      lastDice2: state.lastDice2,
      lastDiceRollId: state.lastDiceRollId,
    );
  }

  // Actualiza el jugador activo basándose en la orden explícita del servidor
  void setActivePlayerName(String? name, {int? round}) {
    state = state.copyWith(
      activePlayerName: name,
      currentRound: round ?? state.currentRound,
      hasImprovedDice: false, // Resetear mejora al cambiar de turno
      lastDiceResult:
          null, // Resetear tirada para habilitar objetos de "antes de tirar"
      isMovementActive:
          false, // Asegurar que el estado de movimiento está limpio
      minigameName: null, // Limpiar minijuegos viejos
      minigameDescription: null,
      minigameDetails: null,
      videnteDiceResults: null,
    );
  }

  void setImprovedDice(bool value) {
    state = state.copyWith(hasImprovedDice: value);
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

  void showObtainedItem(String name, String? desc, String player) {
    _rouletteCompleter = Completer<void>();
    state = state.copyWith(
        obtainedItemName: name,
        obtainedItemDesc: desc,
        obtainedItemPlayer: player);
  }

  void hideObtainedItem() {
    state = state.copyWith(clearObtainedItem: true);

    if (_rouletteCompleter != null && !_rouletteCompleter!.isCompleted) {
      _rouletteCompleter!.complete();
    }
  }

  Future<void> waitForRouletteToClose() async {
    if (_rouletteCompleter != null) {
      await _rouletteCompleter!.future;
    }
  }

  void updatePenalty(String playerId, int turns) {
    final updated = state.players
        .map((p) => p.id == playerId ? p.copyWith(penaltyTurns: turns) : p)
        .toList();
    state = state.copyWith(players: updated);
  }

  void showVidenteDice(List<int> diceResults) {
    state = state.copyWith(videnteDiceResults: diceResults);
  }

  void hideVidenteDice() {
    state = GameState(
      currentPhase: state.currentPhase,
      currentRound: state.currentRound,
      players: state.players,
      turnOrder: state.turnOrder,
      activePlayerName: state.activePlayerName,
      serverMessage: state.serverMessage,
      lastDiceResult: state.lastDiceResult,
      lastDice1: state.lastDice1,
      lastDice2: state.lastDice2,
      lastDiceRollId: state.lastDiceRollId,
      minigameName: state.minigameName,
      minigameDescription: state.minigameDescription,
      minigameDetails: state.minigameDetails,
      minigameResults: state.minigameResults,
      minigameChoices: state.minigameChoices,
      isWaitingForMinigameChoice: state.isWaitingForMinigameChoice,
      isMovementActive: state.isMovementActive,
      obtainedItemName: state.obtainedItemName,
      obtainedItemDesc: state.obtainedItemDesc,
      winnerName: state.winnerName,
    );
  }

  // Actualiza el estado de conexión de un jugador
  void setPlayerConnectionStatus(String playerId, bool isConnected) {
    final updatedPlayers = state.players.map((p) {
      if (p.id == playerId || p.username == playerId) {
        return p.copyWith(isConnected: isConnected);
      }
      return p;
    }).toList();

    state = state.copyWith(players: updatedPlayers);
  }

}
