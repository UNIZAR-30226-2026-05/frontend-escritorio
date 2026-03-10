// ==========================================
// ENUMS: Reglas de negocio del documento
// ==========================================

/// RF08 - Clases de personajes con habilidades únicas
enum CharacterClass {
  banquero,     // Roba monedas
  videojugador, // Elige minijuegos
  escapista,    // Reduce penalizaciones
  vidente       // Ve el resultado de los dados antes
}

/// RF06.1 - Tipos de dados ganados en los minijuegos
enum DiceType {
  normal, // 1-6
  oro,    // 1-6 extra
  plata,  // 1-4
  bronce, // 1-2
  unico   // 1 dado normal (castigo 4ª posición)
}

/// RF10 - Objetos estratégicos de la tienda
enum ItemType {
  avanzarRetroceder,
  modificadorDado,   // Mejorar/Empeorar dados
  barrera,           // Bloqueo temporal
  robarMonedas,
  ruleta,
  quitarTurno,
  salvavidas         // Eliminar penalización
}

/// Fases del turno global en el servidor
enum GamePhase {
  waitingForPlayers, // En el Lobby
  minigameOrder,     // Jugando minijuego simultáneo para decidir orden (Tren, Reflejos...)
  boardTurn,         // Los jugadores están tirando dados y moviéndose en el tablero
  minigameTile,      // Evento de casilla (ej. Dilema del prisionero 1v1)
  finished           // Partida terminada
}


// Clase de jugador
// TODO Añadir los métodos de serialización para intercambiar
// los datos con el backend
class Player {
  // RF01 - Identificación básica
  final String id;
  final String username;
  
  // RF08 - Personaje elegido
  final CharacterClass characterClass;  // Clase del personaje

  // RF05 - Tablero
  final int currentTileIndex;   // Casilla actual
  
  // RF09 - Economía
  final int coins;              // Monedas

  // RF06 & RF10 - Inventarios
  final List<DiceType> diceInventory; // Dados en el inventario
  final List<ItemType> itemInventory; // Objetos en el inventario

  // RF07 - Gestión de conexión/inactividad
  final bool isConnected;             // Conectado al servidor
  final bool skipNextTurn;            // Para penalizaciones o desconexiones

  // Constructor de la clase
  Player({
    required this.id,
    required this.username,
    required this.characterClass,
    this.currentTileIndex = 0,        // Comienza en la casilla 0
    this.coins = 0,                   // Comienza con 0 monedas
    this.diceInventory = const [],    // Sin dados en el inventario
    this.itemInventory = const [],    // Sin objetos en el inventario
    this.isConnected = true,          // Conectado al servidor
    this.skipNextTurn = false,        // No se salta el turno
  });

  // copyWith es vital para la inmutabilidad (Riverpod / BLoC)
  // Permite crear copias de la clase con valores modificados
  // en lugar de cambiar los valores directamente
  // Si se cambian los valores directamente, Riverpod no detecta los cambios
  // Es necesario para actualizar el estado del juego en la UI
  Player copyWith({
    String? id,
    String? username,
    CharacterClass? characterClass,
    int? currentTileIndex,
    int? coins,
    List<DiceType>? diceInventory,
    List<ItemType>? itemInventory,
    bool? isConnected,
    bool? skipNextTurn,
    //Los '?' significan que los parámetros son opcionales
    //Si no se proporciona un valor, se usa el valor por defecto
  }) {
    return Player(
      id: id ?? this.id,
      username: username ?? this.username,
      characterClass: characterClass ?? this.characterClass,
      currentTileIndex: currentTileIndex ?? this.currentTileIndex,
      coins: coins ?? this.coins,
      diceInventory: diceInventory ?? this.diceInventory,
      itemInventory: itemInventory ?? this.itemInventory,
      isConnected: isConnected ?? this.isConnected,
      skipNextTurn: skipNextTurn ?? this.skipNextTurn,
      // Los '??' significan que si no se proporciona el valor de la izquierda, 
      // se de el de la derecha. El de la derecha cambia las cosas al default
    );
  }
}

// Clase del estado del juego
// TODO Añadir los métodos de serialización para intercambiar
// los datos con el backend
class GameState {
  // Estado global
  final GamePhase currentPhase;
  final int currentRound; // Cada vez que los 4 tiran, sube la ronda
  
  // Jugadores
  final List<Player> players;
  final List<String> turnOrder; // IDs de los jugadores ordenados tras el minijuego de orden (RF06)
  final int activePlayerIndex; // Índice sobre turnOrder para saber quién tira ahora

  // UI / Feedback
  final String serverMessage;
  final int? lastDiceResult; // Solo para mostrar visualmente cuánto sacó

  //Constructor de la clase
  GameState({
    this.currentPhase = GamePhase.waitingForPlayers,
    this.currentRound = 1,
    required this.players,
    this.turnOrder = const [],
    this.activePlayerIndex = 0,
    this.serverMessage = "Esperando jugadores...",
    this.lastDiceResult,
  });
  
  GameState copyWith({
    GamePhase? currentPhase,
    int? currentRound,
    List<Player>? players,
    List<String>? turnOrder,
    int? activePlayerIndex,
    String? serverMessage,
    int? lastDiceResult,
  }) {
    return GameState(
      currentPhase: currentPhase ?? this.currentPhase,
      currentRound: currentRound ?? this.currentRound,
      players: players ?? this.players,
      turnOrder: turnOrder ?? this.turnOrder,
      activePlayerIndex: activePlayerIndex ?? this.activePlayerIndex,
      serverMessage: serverMessage ?? this.serverMessage,
      lastDiceResult: lastDiceResult ?? this.lastDiceResult,
    );
  }
}