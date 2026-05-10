import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  // Cola FIFO de destinatarios de send_request a la espera de confirmación.
  // Si llega un error del back asumimos que corresponde al envío más antiguo
  // sin resolver y revertimos la marca "Pendiente" de ese usuario.
  final List<String> _pendingFriendRequestTargets = [];

  // Timers de expiración de invitaciones enviadas. Si el destinatario no acepta
  // en 45 s se elimina la marca "Invitado" para permitir reenvío.
  final Map<String, Timer> _inviteExpireTimers = {};

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

      // Pide la lista de amigos online nada más conectar.
      _sendRaw({'action': 'get_online_friends'});

      // Obtiene la lista completa de amigos (online + offline) vía HTTP.
      _ref.read(lobbyProvider.notifier).fetchAllFriends(username, token);

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

      // Errores genéricos del back en formato {"error": "..."}. El back no
      // especifica a qué acción pertenece el error, pero en la práctica las
      // respuestas del WS llegan en orden, así que asumimos que corresponde al
      // envío más antiguo pendiente de la cola de solicitudes de amistad.
      if (decoded.containsKey('error')) {
        final errorMsg = decoded['error']?.toString() ?? 'Error desconocido';
        if (_pendingFriendRequestTargets.isNotEmpty) {
          final target = _pendingFriendRequestTargets.removeAt(0);
          notifier.clearFriendRequestSent(target);
          notifier.setFriendRequestError(
            'No se pudo enviar la solicitud a "$target": $errorMsg',
          );
        } else {
          notifier.setFriendRequestError(errorMsg);
        }
        return;
      }

      debugPrint(
          'Mensaje WS recibido: $decoded'); // Debug: log de mensajes entrantes
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
          debugPrint(
              'Lista de solicitudes de amistad recibida: ${decoded['lista']}');
          final list = (decoded['lista'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          notifier.onFriendRequestsList(list);
          break;

        // Respuesta a get_online_friends: lista de amigos conectados.
        case 'online_friends_list':
          final friends = (decoded['friends'] as List<dynamic>? ?? [])
              .map((e) => e.toString())
              .toList();
          notifier.onOnlineFriendsList(friends);
          break;


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

        // El destinatario rechazó nuestra invitación: permitimos reenviarla.
        case 'invite_declined':
        case 'invite_rejected':
          final fromUser = decoded['from_user']?.toString() ?? decoded['friend_id']?.toString() ?? '';
          if (fromUser.isNotEmpty) {
            _inviteExpireTimers[fromUser]?.cancel();
            _inviteExpireTimers.remove(fromUser);
            notifier.clearInviteSent(fromUser);
          }
          break;

        // Un usuario nos envía una nueva solicitud de amistad en tiempo real.
        case 'new_friend_request':
          final fromUser = decoded['from_user']?.toString() ?? '';
          if (fromUser.isNotEmpty) notifier.addFriendRequest(fromUser);
          break;

        // El backend confirma que nuestra solicitud de amistad se envió.
        case 'request_sended':
          if (_pendingFriendRequestTargets.isNotEmpty) {
            _pendingFriendRequestTargets.removeAt(0);
          }
          break;

        // El backend rechaza nuestra solicitud (ya amigos o solicitud duplicada).
        case 'failed_request':
          final target = _pendingFriendRequestTargets.isNotEmpty
              ? _pendingFriendRequestTargets.removeAt(0)
              : decoded['username']?.toString() ?? 'Usuario desconocido';
          notifier.clearFriendRequestSent(target);
          final cause = decoded['cause']?.toString() ?? 'Error desconocido';
          notifier.setFriendRequestError(
            'Solicitud a "$target" fallida: $cause',
          );
          break;

        case 'user_not_exists':
          final target = _pendingFriendRequestTargets.isNotEmpty
              ? _pendingFriendRequestTargets.removeAt(0)
              : 'Usuario desconocido';
          notifier.clearFriendRequestSent(target);
          notifier.setFriendRequestError('No existe el usuario "$target"');
          debugPrint('Error: Usuario "$target" no existe');
          break;

        default:
          debugPrint('Mensaje WS de sesión no manejado: $decoded');
          break;
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

  void inviteFriend(String friendId, String gameId) {
    _sendRaw({
      'action': 'invite_friend',
      'payload': {
        'friend_id': friendId,
        'game_id': gameId,
      }
    });
    _ref.read(lobbyProvider.notifier).markInviteSent(friendId);

    // Expira la marca "Invitado" tras 45 s si el destinatario no acepta/rechaza.
    _inviteExpireTimers[friendId]?.cancel();
    _inviteExpireTimers[friendId] = Timer(
      const Duration(seconds: 45),
      () {
        _inviteExpireTimers.remove(friendId);
        _ref.read(lobbyProvider.notifier).clearInviteSent(friendId);
      },
    );
  }

  // Envía una solicitud de amistad a otro usuario.
  void sendFriendRequest(String playerId) {
    _sendRaw({
      'action': 'send_request',
      'payload': {'player_id': playerId}
    });
    // Marca localmente la solicitud como pendiente para que la UI muestre
    // "Pendiente" sin esperar un eco del servidor. Si el back responde con
    // error (p. ej. usuario inexistente), el listener revertirá esta marca.
    _ref.read(lobbyProvider.notifier).markFriendRequestSent(playerId);
    _pendingFriendRequestTargets.add(playerId);
  }

  // Acepta una solicitud de amistad pendiente.
  void acceptFriendRequest(String playerId) {
    _sendRaw({
      'action': 'accept_request',
      'payload': {'player_id': playerId}
    });
    _ref.read(lobbyProvider.notifier).removeFriendRequest(playerId);
    _sendRaw({'action': 'get_online_friends'});
    // Refresca la lista completa de amigos para incluir al recién aceptado.
    if (_savedUsername != null && _savedToken != null) {
      _ref.read(lobbyProvider.notifier).fetchAllFriends(_savedUsername!, _savedToken!);
    }
  }

  // Rechaza una solicitud de amistad pendiente.
  void rejectFriendRequest(String playerId) {
    _sendRaw({
      'action': 'reject_request',
      'payload': {'player_id': playerId}
    });
    _ref.read(lobbyProvider.notifier).removeFriendRequest(playerId);
  }

  // Cierra la conexión de forma intencionada y resetea el estado de reconexión.
  void disconnect() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    for (final t in _inviteExpireTimers.values) {
      t.cancel();
    }
    _inviteExpireTimers.clear();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _savedUsername = null;
    _savedToken = null;
  }
}
