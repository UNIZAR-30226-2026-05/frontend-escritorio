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
  bool get isAnimationQueueEmpty => _animationQueue.isEmpty;

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


  Future<void> updatePlayerFromBackend(String playerId, int newTileIndex, int diceRoll) async {
    final completer = Completer<void>();

    _animationQueue.add(() async {
      await _performUpdatePlayer(playerId, newTileIndex, diceRoll);
      completer.complete();
    });

    _processQueue();
    // Devolvemos el future para que el websocket_service espere a que termine ESTA animación
    // antes de enviar el _sendEndRound()
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
  Future<void> _performUpdatePlayer(String playerId, int newTileIndex, int diceRoll) async {
    if (state.currentPhase == GamePhase.finished) return;

    final currentPlayer = state.players.firstWhere((p) => p.id == playerId);

    // DEBUG DETALLADO
    print(' ACTUALIZANDO JUGADOR:');
    print('  Jugador: ${currentPlayer.username} (ID: $playerId)');
    print('  Posición ACTUAL: ${currentPlayer.currentTileIndex}');
    print('  Dado tirado: $diceRoll');
    print('  Nueva casilla (del backend): $newTileIndex');
    print('  Diferencia: ${newTileIndex - currentPlayer.currentTileIndex}');
    print('  ¿Coincide dado con diferencia?: ${diceRoll == (newTileIndex - currentPlayer.currentTileIndex)}');
    print('  Total jugadores: ${state.players.length}');
    print('  Turno order: ${state.turnOrder}');
    print('  Active player index actual: ${state.activePlayerIndex}');
    print('  Próximo index: ${(state.activePlayerIndex + 1) % state.turnOrder.length}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Mensaje según si es movimiento o corrección
    String newMessage = diceRoll == 0
      ? "${currentPlayer.username} ajusta su posición."
      : "${currentPlayer.username} sacó un $diceRoll.";

    // Animación de movimiento paso a paso (funciona tanto para avance como retroceso)
    final startPos = currentPlayer.currentTileIndex;

    // Nos aseguramos de que el nuevo índice no supere el máximo del tablero
    final endPos = newTileIndex >= totalTiles - 1 ? totalTiles - 1 : newTileIndex;    final isMovingForward = endPos > startPos;

    if (isMovingForward) {
      // Avance: 5 → 9 (5, 6, 7, 8, 9)
      for (int i = startPos + 1; i <= endPos; i++) {
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
            lastDiceResult: diceRoll == 0 ? state.lastDiceResult : diceRoll);

        await Future.delayed(const Duration(milliseconds: 350));
      }
    } else {
      // Retroceso: 9 → 5 (9, 8, 7, 6, 5)
      for (int i = startPos - 1; i >= endPos; i--) {
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
            lastDiceResult: diceRoll == 0 ? state.lastDiceResult : diceRoll);

        await Future.delayed(const Duration(milliseconds: 350));
      }
    }

    GamePhase nextPhase = state.currentPhase;

    if (newTileIndex >= totalTiles - 1) {
      nextPhase = GamePhase.finished;
      newMessage = "¡${currentPlayer.username} HA GANADO LA PARTIDA!";
    }

    if (diceRoll != 0) {
      int nextPlayerIndex = (state.activePlayerIndex + 1) % state.turnOrder.length;
      int nextRound = state.currentRound;

      // Si el índice vuelve a 0, significa que ha dado la vuelta completa a todos los jugadores
      if (nextPlayerIndex == 0) {
        nextRound += 1;
      }

      state = state.copyWith(
        activePlayerIndex: nextPlayerIndex,
        currentRound: nextRound,
        serverMessage: newMessage,
        currentPhase: nextPhase,
      );
    } else {
      state = state.copyWith(
        serverMessage: newMessage,
        currentPhase: nextPhase,
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

    print('═══════════════════════════════════════════');
    print(' SYNC BOARD STATE - Datos del backend:');
    print('  • Número de jugadores: ${positions.length}');
    print('  • Posiciones: $positions');
    print('  • Orden: $order');
    print('  • Caracteres: $characters');
    print('  • Balances: $balances');
    print('═══════════════════════════════════════════');

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
        if (charString.contains('escapista'))
          charClass = CharacterClass.escapista;
        else if (charString.contains('vidente'))
          charClass = CharacterClass.vidente;
        else if (charString.contains('videojugador'))
          charClass = CharacterClass.videojugador;
        else
          charClass = CharacterClass.banquero;
      }

      updatedPlayers.add(existingPlayer.copyWith(
        currentTileIndex:
            (pos as int) - 1, // El backend usa 1-indexed, nosotros 0-indexed
        coins: balances[username] as int? ?? 0,
        characterClass: charClass,
      ));

      // Guardar el orden de turno (el backend da base 1, array base 0)
      if (playerOrder > 0 && playerOrder <= newTurnOrder.length) {
        newTurnOrder[playerOrder - 1] = id;
      }
    });

    // Filtramos vacíos por si alguien falta en el order (ej: test con 1 player)
    final cleanTurnOrder = newTurnOrder.where((id) => id.isNotEmpty).toList();

      print('✅ Jugadores cargados del backend:');
      for (var p in updatedPlayers) {
        print('  • ${p.username} (ID: ${p.id}) - Casilla ${p.currentTileIndex} - ${p.characterClass.name}');
      }
      print('  Turno order: $cleanTurnOrder');
      print('═══════════════════════════════════════════');

    state = state.copyWith(
      currentPhase: newPhase,
      players: updatedPlayers.isNotEmpty ? updatedPlayers : state.players,
      turnOrder: cleanTurnOrder.isNotEmpty ? cleanTurnOrder : state.turnOrder,
      serverMessage: "Sincronizado con el servidor",
    );
  }

  // Método para actualizar monedas e inventario
  void updateInventoryAndBalance(String playerId, {List<ItemType>? newInventory, int? newBalance}) {
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

}
