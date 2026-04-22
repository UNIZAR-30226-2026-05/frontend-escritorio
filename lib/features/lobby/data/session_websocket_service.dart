import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/api_constants.dart';
import '../domain/lobby_models.dart';
import '../presentation/controllers/lobby_provider.dart';

// Provider único para acceder al servicio de sesión en toda la app.
final sessionWebSocketProvider = Provider<SessionWebSocketService>((ref) {
  return SessionWebSocketService(ref);
});

// Gestiona la conexión WebSocket de SESIÓN (/ws/usuario/{user}).
// Esta conexión vive mientras el usuario está autenticado y se usa para:
//   - Recibir y enviar invitaciones de partida entre amigos.
//   - Mantener el estado online/offline de los amigos.
//   - Gestionar solicitudes de amistad (listado inicial, aceptar, rechazar).
// Es independiente del WS de partida, que solo existe durante una partida.
class SessionWebSocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  bool _isConnected = false;

  // Credenciales para reconexión automática si se cae la conexión.
  String? _savedUsername;
  String? _savedToken;
  bool _intentionalDisconnect = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  SessionWebSocketService(this._ref);

  // Abre la conexión al WS de sesión usando el username y token.
  // Si ya había una conexión activa se ignora la llamada.
  void connect(String username, String token) {
    if (_isConnected) return;

    _savedUsername = username;
    _savedToken = token;
    _intentionalDisconnect = false;

    final url = ApiConstants.wsUsuarioUrl(username, token);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;

      _channel!.stream.listen(
        (message) => _handleIncomingMessage(message.toString()),
        onDone: () {
          _isConnected = false;
          if (!_intentionalDisconnect) _scheduleReconnect();
        },
        onError: (error) {
          _isConnected = false;
          if (!_intentionalDisconnect) _scheduleReconnect();
        },
      );

      // Pide la lista de amigos online nada más conectar para rellenar la UI
      // sin esperar a los cambios de estado en tiempo real.
      _sendRaw({'action': 'get_online_friends'});
    } catch (_) {
      _isConnected = false;
      if (!_intentionalDisconnect) _scheduleReconnect();
    }
  }

  // Retardo exponencial: 2s, 4s, 8s, 16s, 32s. Tras _maxReconnectAttempts se abandona.
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    final delay = Duration(seconds: 2 << _reconnectAttempts);
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () {
      if (!_intentionalDisconnect &&
          _savedUsername != null &&
          _savedToken != null) {
        connect(_savedUsername!, _savedToken!);
      }
    });
  }

  // Procesa los mensajes entrantes y despacha al LobbyController.
  void _handleIncomingMessage(String message) {
    try {
      final decoded = jsonDecode(message) as Map<String, dynamic>;
      final notifier = _ref.read(lobbyProvider.notifier);

      switch (decoded['type'] as String?) {
        // Amigo cambia entre online/offline.
        case 'friend_status_update':
          final friendId = decoded['friend_id'] as String? ?? '';
          final status = decoded['status'] as String? ?? 'offline';
          if (friendId.isNotEmpty) {
            notifier.onFriendStatusUpdate(friendId, status);
          }
          break;

        // Lista de solicitudes pendientes al iniciar sesión.
        case 'friend_requests_list':
          final list = (decoded['lista'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          notifier.onFriendRequestsList(list);
          break;

        default:
          // El campo 'action' lo usa el backend para ciertos eventos como
          // 'receive_invite' o nuevas solicitudes de amistad entrantes.
          final action = decoded['action'] as String?;
          switch (action) {
            // Un amigo nos ha invitado a su partida.
            case 'receive_invite':
              final fromUser = decoded['from_user']?.toString() ?? '';
              final gameId = decoded['game_id']?.toString() ?? '';
              if (fromUser.isNotEmpty && gameId.isNotEmpty) {
                notifier.onInviteReceived(
                  GameInvite(fromUser: fromUser, gameId: gameId),
                );
              }
              break;
            // Un usuario nos envía una nueva solicitud de amistad.
            case 'send_request':
              final fromUser = decoded['player_id']?.toString() ?? '';
              if (fromUser.isNotEmpty) notifier.addFriendRequest(fromUser);
              break;
            default:
              break;
          }
      }
    } catch (_) {
      // Mensaje mal formado: se ignora.
    }
  }

  // Envío genérico por el WS. No-op si la conexión no está lista.
  void _sendRaw(Map<String, dynamic> payload) {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode(payload));
  }

  // Invita a un amigo a la partida actual. El backend asocia la invitación
  // al game_id en el que estemos; lo mandamos igualmente para ser explícitos.
  void inviteFriend(String friendId, String gameId) {
    _sendRaw({
      'action': 'invite_friend',
      'player_id': friendId,
      'game_id': gameId,
    });
    _ref.read(lobbyProvider.notifier).markInviteSent(friendId);
  }

  // Envía una solicitud de amistad a otro usuario.
  void sendFriendRequest(String playerId) {
    _sendRaw({'action': 'send_request', 'player_id': playerId});
  }

  // Acepta una solicitud de amistad pendiente.
  void acceptFriendRequest(String playerId) {
    _sendRaw({'action': 'accept_request', 'player_id': playerId});
    _ref.read(lobbyProvider.notifier).removeFriendRequest(playerId);
  }

  // Rechaza una solicitud de amistad pendiente.
  void rejectFriendRequest(String playerId) {
    _sendRaw({'action': 'reject_request', 'player_id': playerId});
    _ref.read(lobbyProvider.notifier).removeFriendRequest(playerId);
  }

  // Cierra la conexión de forma intencionada y resetea el estado de reconexión.
  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _savedUsername = null;
    _savedToken = null;
  }
}
