// ==========================================
// ENUMS: Reglas de negocio del documento
// ==========================================

/// RF08 - Clases de personajes con habilidades únicas
enum CharacterClass {
  banquero, // Roba monedas
  videojugador, // Elige minijuegos
  escapista, // Reduce penalizaciones
  vidente // Ve el resultado de los dados antes
}

/// RF06.1 - Tipos de dados ganados en los minijuegos
enum DiceType {
  normal, // 1-6
  oro, // 1-6 extra
  plata, // 1-4
  bronce, // 1-2
  unico // 1 dado normal (castigo 4ª posición)
}

/// RF10 - Objetos estratégicos de la tienda
enum ItemType {
  avanzarRetroceder,
  modificadorDado, // Mejorar/Empeorar dados
  barrera, // Bloqueo temporal
  robarMonedas,
  ruleta,
  quitarTurno,
  salvavidas // Eliminar penalización
}

/// Fases del turno global en el servidor
enum GamePhase {
  waitingForPlayers, // En el Lobby
  minigameOrder, // Jugando minijuego simultáneo para decidir orden (Tren, Reflejos...)
  boardTurn, // Los jugadores están tirando dados y moviéndose en el tablero
  minigameTile, // Evento de casilla (ej. Dilema del prisionero 1v1)
  finished // Partida terminada
}

// Clase de jugador
// Añadidos los métodos de serialización para intercambiar
// los datos con el backend
class Player {
  // RF01 - Identificación básica
  final String id;
  final String username;

  // RF08 - Personaje elegido
  final CharacterClass characterClass; // Clase del personaje

  // RF05 - Tablero
  final int currentTileIndex; // Casilla actual

  // RF09 - Economía
  final int coins; // Monedas

  // RF06 & RF10 - Inventarios
  final List<DiceType> diceInventory; // Dados en el inventario
  final List<ItemType> itemInventory; // Objetos en el inventario

  // RF07 - Gestión de conexión/inactividad
  final bool isConnected; // Conectado al servidor
  final bool skipNextTurn; // Para penalizaciones o desconexiones

  final int penaltyTurns; //Para turnos de penalización

  // Constructor de la clase
  Player({
    required this.id,
    required this.username,
    required this.characterClass,
    this.currentTileIndex = 0, // Comienza en la casilla 0
    this.coins = 0, // Comienza con 0 monedas
    this.diceInventory = const [], // Sin dados en el inventario
    this.itemInventory = const [], // Sin objetos en el inventario
    this.isConnected = true, // Conectado al servidor
    this.skipNextTurn = false, // No se salta el turno
    this.penaltyTurns = 0,
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
    int? penaltyTurns,
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
      penaltyTurns: penaltyTurns ?? this.penaltyTurns,
      // Los '??' significan que si no se proporciona el valor de la izquierda,
      // se de el de la derecha. El de la derecha cambia las cosas al default
    );
  }

  // Deserialización para WebSockets a partir del mapa de strings json
  factory Player.fromJson(Map<String, dynamic> json) {
    // Se devuelve un nuevo jugador con los campos que devuelva el backend
    return Player(
      // Cada campo es o el del json o uno por defecto excepto characterClass
      id: json['id'] ?? '',
      username: json['username'] ?? 'Jugador Desconocido',
      characterClass: _parseCharacterClass(
          json['characterClass']), //se usa la función de abajo
      // Esto se hace porque los JSON solo pueden enviar tipos de
      // datos básicos (como string o int), pero nosotros usamos
      // el Enum CharacterClass. Así lo podemos devolver
      currentTileIndex: json['currentTileIndex'] ?? 0,
      coins: json['coins'] ?? 0,
      isConnected: json['isConnected'] ?? true,
      skipNextTurn: json['skipNextTurn'] ?? false,
      // Los inventarios se mapearían si el backend los enviara (todavía no es la versión)
      diceInventory: [],
      itemInventory: [],
      // Turnos saltados
      penaltyTurns: json['penaltyTurns'] ?? 0,
    );
  }

  // Función para parsear la clase del personaje dado un string nulleable
  // Si no hay ninguno es el banquero
  // Devuelve un CharacterClass
  static CharacterClass _parseCharacterClass(String? value) {
    if (value == null) return CharacterClass.banquero;
    return CharacterClass.values.firstWhere(
      // Devuelve el nombre que sea igual a algún nombre de los CharacterClass
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () =>
          CharacterClass.banquero, // Si ninguno es igual se devuelve banquero
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
  final List<String>
      turnOrder; // IDs de los jugadores ordenados tras el minijuego de orden (RF06)
  final int
      activePlayerIndex; // Índice sobre turnOrder para saber quién tira ahora

  // UI / Feedback
  final String serverMessage;
  final int? lastDiceResult; // Solo para mostrar visualmente cuánto sacó
  final int lastDice1; // Valor del dado 1 individual
  final int
      lastDice2; // Valor del dado 2 individual (0 si no hubo segundo dado)
  final int
      lastDiceRollId; // Contador incremental para detectar rollos seguidos idénticos

  // Minijuegos
  final String? minigameName;
  final String? minigameDescription;
  final Map<String, dynamic>? minigameDetails;
  final Map<String, dynamic>? minigameResults;
  final List<String>? minigameChoices;
  final bool isWaitingForMinigameChoice;

  //Objetos del tablero (ruleta)
  final String? obtainedItemName;
  final String? obtainedItemDesc;

  // Animaciones / Locks
  final bool isMovementActive;

  //Constructor de la clase
  GameState({
    this.currentPhase = GamePhase.waitingForPlayers,
    this.currentRound = 1,
    required this.players,
    this.turnOrder = const [],
    this.activePlayerIndex = 0,
    this.serverMessage = "Esperando jugadores...",
    this.lastDiceResult,
    this.lastDice1 = 0,
    this.lastDice2 = 0,
    this.lastDiceRollId = 0,
    this.minigameName,
    this.minigameDescription,
    this.minigameDetails,
    this.minigameResults,
    this.minigameChoices,
    this.isWaitingForMinigameChoice = false,
    this.isMovementActive = false,
    this.obtainedItemName,
    this.obtainedItemDesc,
  });

  GameState copyWith({
    GamePhase? currentPhase,
    int? currentRound,
    List<Player>? players,
    List<String>? turnOrder,
    int? activePlayerIndex,
    String? serverMessage,
    int? lastDiceResult,
    int? lastDice1,
    int? lastDice2,
    int? lastDiceRollId,
    String? minigameName,
    String? minigameDescription,
    Map<String, dynamic>? minigameDetails,
    Map<String, dynamic>? minigameResults,
    List<String>? minigameChoices,
    bool? isWaitingForMinigameChoice,
    bool? isMovementActive,
    String? obtainedItemName,
    String? obtainedItemDesc,
  }) {
    return GameState(
      currentPhase: currentPhase ?? this.currentPhase,
      currentRound: currentRound ?? this.currentRound,
      players: players ?? this.players,
      turnOrder: turnOrder ?? this.turnOrder,
      activePlayerIndex: activePlayerIndex ?? this.activePlayerIndex,
      serverMessage: serverMessage ?? this.serverMessage,
      lastDiceResult: lastDiceResult ?? this.lastDiceResult,
      lastDice1: lastDice1 ?? this.lastDice1,
      lastDice2: lastDice2 ?? this.lastDice2,
      lastDiceRollId: lastDiceRollId ?? this.lastDiceRollId,
      minigameName: minigameName ?? this.minigameName,
      minigameDescription: minigameDescription ?? this.minigameDescription,
      minigameDetails: minigameDetails ?? this.minigameDetails,
      minigameResults: minigameResults ?? this.minigameResults,
      minigameChoices: minigameChoices ?? this.minigameChoices,
      isWaitingForMinigameChoice:
          isWaitingForMinigameChoice ?? this.isWaitingForMinigameChoice,
      isMovementActive: isMovementActive ?? this.isMovementActive,
      obtainedItemName: obtainedItemName ?? this.obtainedItemName,
      obtainedItemDesc: obtainedItemDesc ?? this.obtainedItemDesc,
    );
  }
}
