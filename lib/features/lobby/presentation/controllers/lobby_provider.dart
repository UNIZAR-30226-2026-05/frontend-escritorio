import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lobby_service.dart';
import '../../domain/lobby_models.dart';

// Define la clase que representa el estado del lobby.
class LobbyState {
  // Identificador de la partida actual (obtenido al crear o unirse).
  final String? gameId;
  // Lista de nombres de jugadores actualmente conectados a la partida.
  final List<String> playersConnected;
  // Lista de invitaciones a partidas recibidas por el WebSocket de sesión.
  final List<GameInvite> invites;
  // Conjunto de usernames de amigos actualmente online.
  // Se actualiza con cada mensaje 'friend_status_update' del WS de sesión.
  final Set<String> onlineFriends;
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
    this.invites = const [],
    this.onlineFriends = const {},
    this.gameStarted = false,
    this.forceDisconnected = false,
    this.serverMessage = '',
    this.isLoading = false,
    this.error,
  });

  // Crea una copia del estado cambiando solo los campos indicados.
  // Metodo común en Flutter para actualizar el estado de forma inmutable.
  // Usado en el controlador para modificar solo partes del estado sin afectar lo demás.
  LobbyState copyWith({
    String? gameId,
    List<String>? playersConnected,
    List<GameInvite>? invites,
    Set<String>? onlineFriends,
    bool? gameStarted,
    bool? forceDisconnected,
    String? serverMessage,
    bool? isLoading,
    String? error,
    // Estas variables permiten forzar a null campos específicos aunque se pase un valor para ellos.
    bool clearGameId = false,
    bool clearError = false,
  }) =>
      LobbyState(
        // Si se pasa un nuevo valor para cada campo, se usa ese. Si no, se mantiene el valor actual del estado.
        playersConnected: playersConnected ?? this.playersConnected,
        invites: invites ?? this.invites,
        onlineFriends: onlineFriends ?? this.onlineFriends,
        gameStarted: gameStarted ?? this.gameStarted,
        forceDisconnected: forceDisconnected ?? this.forceDisconnected,
        serverMessage: serverMessage ?? this.serverMessage,
        isLoading: isLoading ?? this.isLoading,
        // Si clearGameId es true, se fuerza a null aunque se pase un gameId. 
        // Si clearError es true, se fuerza a null aunque se pase un error.   
        gameId: clearGameId ? null : (gameId ?? this.gameId),
        error: clearError ? null : (error ?? this.error),
      );
}

// El controlador que gestiona el estado del lobby.
// StateNotifier es una clase de Riverpod que permite emitir nuevos estados de forma inmutable y notificar 
// a los widgets que estén escuchando para que se reconstruyan con el nuevo estado.     
class LobbyController extends StateNotifier<LobbyState> {
  // Referencia al servicio de comunicacion http del lobby.
  final LobbyService _lobbyService;
  // Constructor, inicializa el estado vacío.
  LobbyController(this._lobbyService) : super(const LobbyState());


  // Operaciones de comunicacion http.
  // -------------------------------------------------------------------------
  // Metodo publico que se llama desde el controlador para crear una partida. 
  // Crea una nueva partida y guarda el game_id para conectar el WebSocket.
  Future<bool> crearPartida(String token) async {
    // Actualiza el estado para indicar que se está esperando la respuesta y limpiar errores previos.
    state = state.copyWith(isLoading: true, clearError: true);
    // Llama al servicio para crear la partida. Si tiene éxito, guarda el game_id en el estado. Si falla, guarda el error.
    try {
      final response = await _lobbyService.crearPartida(token);
      state = state.copyWith(gameId: response.gameId, playersConnected: [], isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', ''),);
      return false;
    }
  }

  // Llama al endpoint para validar que la partida existe y tiene hueco.
  // Si el servidor acepta, devuelve true y el caller conecta el WebSocket.
  // Si falla, guarda el error en el estado y devuelve false.
  Future<bool> unirsePartida(String gameId, String token) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _lobbyService.unirsePartida(gameId, token);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  // Guarda el game_id cuando el WS confirma con lobby_update que el jugador está dentro.
  void unirseAPartida(String gameId) {
    state = state.copyWith(gameId: gameId);
  }


  // Callbacks del WebSocket de sesión.
  // -------------------------------------------------------------------------
  // Llamado por el WS de sesión cuando llega 'receive_invite'.
  // Añade la invitación a la lista para que la UI la muestre al usuario.
  void onInviteReceived(GameInvite invite) {
    state = state.copyWith(invites: [...state.invites, invite]);
  }

  // Elimina una invitación de la lista (al aceptarla o rechazarla).
  void removeInvite(String gameId) {
    state = state.copyWith(invites: state.invites.where((i) => i.gameId != gameId).toList(),);
  }

  // Llamado por el WS de sesión cuando llega 'friend_status_update'.
  // Añade o elimina el amigo del conjunto según su nuevo estado online/offline.
  void onFriendStatusUpdate(String friendId, String status) {
    final updated = {...state.onlineFriends};
    if (status == 'online') {
      updated.add(friendId);
    } else {
      updated.remove(friendId);
    }
    state = state.copyWith(onlineFriends: updated);
  }


  // Callbacks del WebSocket del lobby.
  // -------------------------------------------------------------------------
  // Llamado por el WebSocket cuando llega 'lobby_update'.
  // Actualiza la lista de jugadores conectados a la partida y el mensaje del servidor.
  void onLobbyUpdate(List<String> players, String message) {
    state = state.copyWith(playersConnected: players, serverMessage: message,);
  }

  // Llamado por el WebSocket cuando llega 'game_start'.
  // Indica que los 4 jugadores se han conectado y empieza la selección de personaje.
  void onGameStart() {
    state = state.copyWith(gameStarted: true);
  }

  // Llamado por el WebSocket cuando llega 'player_disconnected'.
  // Actualiza la lista de jugadores conectados a la partida y el mensaje del servidor para informar al usuario.
  void onPlayerDisconnected(List<String> players, String message) {
    state = state.copyWith(playersConnected: players, serverMessage: message,);
  }

  // Llamado por el WebSocket cuando llega 'force_disconnect'.
  // Otro dispositivo tomó la conexión: limpia la sesión y avisa a la UI.
  void onForceDisconnect(String message) {
    state = state.copyWith(
      forceDisconnected: true,
      serverMessage: message,
      clearGameId: true,
      playersConnected: [],
      gameStarted: false,
    );
  }

  // Resetea el flag forceDisconnected una vez que la UI ha mostrado el aviso.
  void clearForceDisconnected() {
    state = state.copyWith(forceDisconnected: false, serverMessage: '');
  }

  // Llamado por el WebSocket cuando llega 'reconnect_success' con status WAITING.
  // El jugador se ha reconectado a una partida que sigue esperando jugadores.
  void onReconnectSuccess(dynamic boardState) {
    state = state.copyWith(serverMessage: 'Reconectado correctamente');
  }

  // Llamado por el WebSocket cuando el backend envía un error genérico
  // (p.ej. "La partida esta llena", "Partida no encontrada").
  // Limpia el gameId y jugadores porque la conexión no fue aceptada.
  void onWsError(String errorMessage) {
    state = state.copyWith(
      error: errorMessage,
      clearGameId: true,
      playersConnected: [],
    );
  }

  // Limpia únicamente los datos de la sesión de partida actual
  // (gameId, jugadores, mensajes, gameStarted) sin tocar invites ni amigos.
  // Útil antes de crear o unirse a una nueva partida.
  void clearGameSession() {
    state = state.copyWith(
      clearGameId: true,
      playersConnected: [],
      gameStarted: false,
      serverMessage: '',
      clearError: true,
    );
  }

  // Utilidades.
  // -------------------------------------------------------------------------
  // Metodo para limpiar el error del estado, usado antes de iniciar 
  // operaciones que pueden fallar para eliminar errores anteriores.
  // Limpia el error actual del estado.
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // Metodo para resetear el estado del lobby, usado al salir de la pantalla de lobby 
  // para limpiar toda la información.
  // Resetea el estado del lobby por completo.
  void reset() {
    state = const LobbyState();
  }
}

// Un provider de tipo Provider que expone el LobbyService a los controladores que lo necesiten.
// Crea y registra una única instancia de LobbyService en el árbol de Riverpod.
final lobbyServiceProvider = Provider<LobbyService>((ref) => LobbyService());

// Un provider de tipo StateNotifierProvider que expone el LobbyController y su estado a los widgets que lo necesiten.
// Crea y registra el LobbyController.
final lobbyProvider = StateNotifierProvider<LobbyController, LobbyState>(
  (ref) => LobbyController(ref.watch(lobbyServiceProvider)),
);
