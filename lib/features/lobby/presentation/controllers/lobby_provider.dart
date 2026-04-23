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
  // Última invitación entrante pendiente de mostrar como notificación.
  // La UI la observa para disparar el SnackBar y después llama a clearLastInvite.
  final GameInvite? lastInvite;
  // Conjunto de usernames de amigos actualmente online.
  // Se actualiza con cada mensaje 'friend_status_update' del WS de sesión.
  final Set<String> onlineFriends;
  // Usernames a los que el jugador local ha enviado una invitacion de partida
  // desde el lobby actual. Sirve para pintar el chip "Invitado".
  // Se limpia al abandonar la partida o al terminarla.
  final Set<String> sentInvites;
  // Usernames a los que el jugador local ha enviado una solicitud de amistad
  // (aún sin aceptar/rechazar por el destinatario). Sirve para pintar el chip
  // "Pendiente" en el buscador de jugadores y evitar reenvíos duplicados.
  final Set<String> sentFriendRequests;
  // Lista de usernames con solicitudes de amistad pendientes de aceptar/rechazar.
  // Se inicializa con 'friend_requests_list' al conectar el WS de sesión.
  final List<String> friendRequests;
  // Último error recibido por el WS de sesión al enviar una solicitud de amistad
  // (por ejemplo, usuario inexistente). La UI lo consume mostrando un SnackBar
  // y llama a clearFriendRequestError para resetearlo.
  final String? friendRequestError;
  // Indica si el juego ha comenzado (los 4 jugadores se han conectado).
  final bool gameStarted;
  // Indica si este dispositivo ha sido desconectado a la fuerza por el backend.
  final bool forceDisconnected;
  // Último mensaje informativo recibido del backend.
  final String serverMessage;
  // Variable que representa el estado de espera de una respuesta de la API.
  final bool isLoading;       // True = esperando respuesta.
  // Estado de los personajes elegidos: username -> personaje
  final Map<String, String> selectedCharacters;
  // Indica si la fase de selección de personajes ha concluido.
  final bool allCharactersSelected;
  // Mensaje de error a mostrar si alguna operación falla.
  final String? error;

  // Constructor con valores por defecto.
  const LobbyState({
    this.gameId,
    this.playersConnected = const [],
    this.invites = const [],
    this.lastInvite,
    this.onlineFriends = const {},
    this.sentInvites = const {},
    this.sentFriendRequests = const {},
    this.friendRequests = const [],
    this.friendRequestError,
    this.gameStarted = false,
    this.selectedCharacters = const {},
    this.allCharactersSelected = false,
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
    GameInvite? lastInvite,
    Set<String>? onlineFriends,
    Set<String>? sentInvites,
    Set<String>? sentFriendRequests,
    List<String>? friendRequests,
    String? friendRequestError,
    bool? gameStarted,
    Map<String, String>? selectedCharacters,
    bool? allCharactersSelected,
    bool? forceDisconnected,
    String? serverMessage,
    bool? isLoading,
    String? error,
    // Estas variables permiten forzar a null campos específicos aunque se pase un valor para ellos.
    bool clearGameId = false,
    bool clearError = false,
    bool clearLastInvite = false,
    bool clearFriendRequestError = false,
  }) =>
      LobbyState(
        // Si se pasa un nuevo valor para cada campo, se usa ese. Si no, se mantiene el valor actual del estado.
        playersConnected: playersConnected ?? this.playersConnected,
        invites: invites ?? this.invites,
        onlineFriends: onlineFriends ?? this.onlineFriends,
        sentInvites: sentInvites ?? this.sentInvites,
        sentFriendRequests: sentFriendRequests ?? this.sentFriendRequests,
        friendRequests: friendRequests ?? this.friendRequests,
        friendRequestError: clearFriendRequestError
            ? null
            : (friendRequestError ?? this.friendRequestError),
        gameStarted: gameStarted ?? this.gameStarted,
        selectedCharacters: selectedCharacters ?? this.selectedCharacters,
        allCharactersSelected: allCharactersSelected ?? this.allCharactersSelected,
        forceDisconnected: forceDisconnected ?? this.forceDisconnected,
        serverMessage: serverMessage ?? this.serverMessage,
        isLoading: isLoading ?? this.isLoading,
        // Si clearGameId es true, se fuerza a null aunque se pase un gameId.
        // Si clearError es true, se fuerza a null aunque se pase un error.
        // Si clearLastInvite es true, se fuerza a null aunque se pase una invitación.
        gameId: clearGameId ? null : (gameId ?? this.gameId),
        error: clearError ? null : (error ?? this.error),
        lastInvite: clearLastInvite ? null : (lastInvite ?? this.lastInvite),
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
  // Añade la invitación al historial y marca lastInvite para que la UI
  // muestre la notificación tipo SnackBar.
  void onInviteReceived(GameInvite invite) {
    state = state.copyWith(
      invites: [...state.invites, invite],
      lastInvite: invite,
    );
  }

  // Consume la última invitación tras mostrar la notificación. El historial
  // en `invites` se mantiene para permitir reabrir notificaciones si se quisiera.
  void clearLastInvite() {
    state = state.copyWith(clearLastInvite: true);
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
      // Si estaba en "pendiente" significa que ya nos ha aceptado: lo limpiamos
      // para que el buscador deje de mostrar el chip "Pendiente".
      final pending = {...state.sentFriendRequests}..remove(friendId);
      state = state.copyWith(
        onlineFriends: updated,
        sentFriendRequests: pending,
      );
      return;
    } else {
      updated.remove(friendId);
      // Si el amigo se desconecta, invalida cualquier invitación pendiente que
      // le hubiéramos enviado: ya no podrá unirse hasta reconectarse.
      final invites = {...state.sentInvites}..remove(friendId);
      state = state.copyWith(onlineFriends: updated, sentInvites: invites);
      return;
    }
  }

  // Llamado por el WS de sesión con la lista de solicitudes de amistad
  // pendientes al conectarse (mensaje 'friend_requests_list').
  void onFriendRequestsList(List<String> requests) {
    state = state.copyWith(friendRequests: requests);
  }

  // Añade una solicitud de amistad entrante recibida en tiempo real.
  // Se usa si el backend notifica nuevas solicitudes después del login.
  void addFriendRequest(String fromUser) {
    if (state.friendRequests.contains(fromUser)) return;
    state = state.copyWith(
      friendRequests: [...state.friendRequests, fromUser],
    );
  }

  // Elimina una solicitud de la lista al aceptarla o rechazarla localmente,
  // sin esperar confirmación del servidor (optimistic update).
  void removeFriendRequest(String fromUser) {
    state = state.copyWith(
      friendRequests:
          state.friendRequests.where((u) => u != fromUser).toList(),
    );
  }

  // Registra que el jugador local ha enviado una invitación de partida al
  // usuario indicado para poder pintar el chip "Invitado" en la UI.
  void markInviteSent(String friendId) {
    if (state.sentInvites.contains(friendId)) return;
    state = state.copyWith(sentInvites: {...state.sentInvites, friendId});
  }

  // Registra que el jugador local ha enviado una solicitud de amistad al
  // usuario indicado. Se usa en el buscador de jugadores para mostrar el chip
  // "Pendiente" y evitar reenvíos duplicados mientras no responda.
  void markFriendRequestSent(String playerId) {
    if (state.sentFriendRequests.contains(playerId)) return;
    state = state.copyWith(
      sentFriendRequests: {...state.sentFriendRequests, playerId},
    );
  }

  // Limpia la marca de solicitud de amistad pendiente (p. ej. cuando la otra
  // persona nos acepta y aparece como amigo online, o si queremos invalidarla).
  void clearFriendRequestSent(String playerId) {
    if (!state.sentFriendRequests.contains(playerId)) return;
    final updated = {...state.sentFriendRequests}..remove(playerId);
    state = state.copyWith(sentFriendRequests: updated);
  }

  // Guarda un mensaje de error devuelto por el WS de sesión al intentar enviar
  // una solicitud de amistad (p. ej. usuario inexistente). La UI lo muestra
  // como SnackBar y después llama a clearFriendRequestError.
  void setFriendRequestError(String message) {
    state = state.copyWith(friendRequestError: message);
  }

  // Limpia el error tras mostrarlo al usuario.
  void clearFriendRequestError() {
    state = state.copyWith(clearFriendRequestError: true);
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

  // Llamado por el WebSocket cuando un jugador selecciona personaje.
  void onPlayerSelected(String user, String character) {
    // Actualizamos el mapa de seleccionados.
    final updated = Map<String, String>.from(state.selectedCharacters);
    updated[user] = character;
    state = state.copyWith(selectedCharacters: updated);
  }

  // Llamado por el WebSocket cuando todos han terminado de elegir.
  void onAllPlayersSelected() {
    state = state.copyWith(allCharactersSelected: true);
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
      selectedCharacters: {},
      allCharactersSelected: false,
      sentInvites: {},
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
      selectedCharacters: {},
      allCharactersSelected: false,
      serverMessage: '',
      clearError: true,
      sentInvites: {},
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
