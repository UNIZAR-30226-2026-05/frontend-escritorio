import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lobby_service.dart';
import '../../domain/lobby_models.dart';

// Define la clase que representa el estado del lobby.
class LobbyState {
  // Identificador de la partida actual (obtenido al crear o unirse).
  final String? gameId;
  // Lista de nombres de jugadores actualmente conectados a la partida.
  final List<String> playersConnected;
  // Lista de partidas disponibles obtenidas del servidor.
  final List<PartidaResumen> partidas;
  // Indica si el juego ha comenzado (los 4 jugadores se han conectado).
  final bool gameStarted;
  // Indica si este dispositivo ha sido desconectado a la fuerza por el backend.
  final bool forceDisconnected;
  // Último mensaje informativo recibido del backend.
  final String serverMessage;
  // Variable que representa el estado de espera de una respuesta de la API.
  final bool isLoading;       // True = esperando respuesta.
  // Mensaje de error a mostrar si alguna operación falla.
  final String? error;
  // Constructor con valores por defecto.
  const LobbyState({
    this.gameId,
    this.playersConnected = const [],
    this.partidas = const [],
    this.gameStarted = false,
    this.forceDisconnected = false,
    this.serverMessage = '',
    this.isLoading = false,
    this.error,
  });
  // Crea una copia del estado cambiando solo los campos indicados.
  LobbyState copyWith({
    String? gameId,
    List<String>? playersConnected,
    List<PartidaResumen>? partidas,
    bool? gameStarted,
    bool? forceDisconnected,
    String? serverMessage,
    bool? isLoading,
    String? error,
    bool clearGameId = false,
    bool clearError = false,
  }) =>
      LobbyState(
        gameId: clearGameId ? null : (gameId ?? this.gameId),
        playersConnected: playersConnected ?? this.playersConnected,
        partidas: partidas ?? this.partidas,
        gameStarted: gameStarted ?? this.gameStarted,
        forceDisconnected: forceDisconnected ?? this.forceDisconnected,
        serverMessage: serverMessage ?? this.serverMessage,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

// El controlador que gestiona el estado del lobby.
class LobbyController extends StateNotifier<LobbyState> {
  // Referencia al servicio REST del lobby.
  final LobbyService _lobbyService;
  // Constructor, inicializa el estado vacío.
  LobbyController(this._lobbyService) : super(const LobbyState());

  // -------------------------------------------------------------------------
  // Operaciones REST
  // -------------------------------------------------------------------------

  // Carga la lista de partidas en estado WAITING.
  Future<void> cargarPartidas(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final partidas = await _lobbyService.listarPartidas(token);
      state = state.copyWith(partidas: partidas, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // Crea una nueva partida y guarda el game_id para conectar el WebSocket.
  Future<bool> crearPartida(String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _lobbyService.crearPartida(token);
      state = state.copyWith(gameId: response.gameId, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  // Guarda el game_id de una partida existente a la que el usuario quiere unirse.
  // Unirse como tal se hace conectando el WebSocket con ese game_id.
  void unirseAPartida(String gameId) {
    state = state.copyWith(gameId: gameId);
  }

  // -------------------------------------------------------------------------
  // Callbacks del WebSocket del lobby
  // -------------------------------------------------------------------------

  // Llamado por el WebSocket cuando llega 'lobby_update'.
  // Actualiza la lista de jugadores conectados y el mensaje del servidor.
  void onLobbyUpdate(List<String> players, String message) {
    state = state.copyWith(
      playersConnected: players,
      serverMessage: message,
    );
  }

  // Llamado por el WebSocket cuando llega 'game_start'.
  // Indica que los 4 jugadores se han conectado y empieza la selección de personaje.
  void onGameStart() {
    state = state.copyWith(gameStarted: true);
  }

  // Llamado por el WebSocket cuando llega 'player_disconnected'.
  // Actualiza el mensaje del servidor para informar al usuario.
  void onPlayerDisconnected(String message) {
    state = state.copyWith(serverMessage: message);
  }

  // Llamado por el WebSocket cuando llega 'force_disconnect'.
  // Marca el estado para que la UI cierre la pantalla de lobby.
  void onForceDisconnect(String message) {
    state = state.copyWith(
      forceDisconnected: true,
      serverMessage: message,
    );
  }

  // Llamado por el WebSocket cuando llega 'reconnect_success'.
  // El jugador se ha reconectado a una partida en curso desde otro dispositivo.
  void onReconnectSuccess(String gameStatus, dynamic boardState) {
    state = state.copyWith(
      gameStarted: gameStatus == 'PLAYING',
      serverMessage: 'Reconectado correctamente',
    );
  }

  // Llamado por el WebSocket cuando el backend envía un error genérico.
  void onWsError(String errorMessage) {
    state = state.copyWith(error: errorMessage);
  }

  // -------------------------------------------------------------------------
  // Utilidades
  // -------------------------------------------------------------------------

  // Limpia el error actual del estado.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Resetea el estado del lobby por completo (p. ej. al cerrar sesión).
  void reset() {
    state = const LobbyState();
  }
}

// Crea y registra una única instancia de LobbyService en el árbol de Riverpod.
final lobbyServiceProvider = Provider<LobbyService>((ref) => LobbyService());

// Crea y registra el LobbyController.
final lobbyProvider = StateNotifierProvider<LobbyController, LobbyState>(
  (ref) => LobbyController(ref.watch(lobbyServiceProvider)),
);
