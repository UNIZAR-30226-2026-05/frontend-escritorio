import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/api_constants.dart';
import '../presentation/controllers/lobby_provider.dart';

// Este Provider nos permite acceder al LobbyWebSocketService en toda la app de forma segura.
final lobbyWebSocketProvider = Provider<LobbyWebSocketService>((ref) {
  return LobbyWebSocketService(ref);
});

// Gestiona la conexión WebSocket durante la fase de LOBBY (estado WAITING).
//
// El backend usa la MISMA URL para lobby y partida:
//   ws://localhost:8080/ws/partida/{gameId}?token={token}
//
// Este servicio se usa mientras se espera a los 4 jugadores.
// Cuando recibe 'game_start' cierra su escucha y la UI navega al tablero,
// donde el WebSocketService de board abrirá su propia conexión.
class LobbyWebSocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  bool _isConnected = false;

  LobbyWebSocketService(this._ref);

  // Conecta al WebSocket de la partida en fase de lobby.
  void connect(String gameId, String token) {
    // Si ya está conectado no se hace nada.
    if (_isConnected) return;

    final url = ApiConstants.wsPartidaUrl(gameId, token);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          _handleIncomingMessage(message.toString());
        },
        // Se ejecuta si la conexión se cierra limpiamente.
        onDone: () {
          _isConnected = false;
          print('LobbyWebSocket: conexión cerrada.');
        },
        // Se ejecuta si la conexión se cierra con error.
        onError: (error) {
          _isConnected = false;
          print('LobbyWebSocket Error: $error');
        },
      );
    } catch (e) {
      _isConnected = false;
      print('LobbyWebSocket: error al conectar → $e');
    }
  }

  // Procesa los mensajes entrantes del backend durante la fase de lobby.
  void _handleIncomingMessage(String message) {
    try {
      final decoded = jsonDecode(message) as Map<String, dynamic>;

      // Comprueba primero si el mensaje es un error genérico del backend.
      if (decoded.containsKey('error')) {
        _ref
            .read(lobbyProvider.notifier)
            .onWsError(decoded['error'] as String);
        return;
      }

      switch (decoded['type'] as String?) {
        // El backend notifica cuántos jugadores están conectados.
        // Payload: { players_connected: [String], message: String }
        case 'lobby_update':
          final List<String> players =
              (decoded['players_connected'] as List<dynamic>? ?? [])
                  .map((p) => p as String)
                  .toList();
          final String msg = decoded['message'] as String? ?? '';
          _ref.read(lobbyProvider.notifier).onLobbyUpdate(players, msg);
          break;

        // Los 4 jugadores se han conectado: empieza la selección de personaje.
        // Payload: { message: String }
        case 'game_start':
          _ref.read(lobbyProvider.notifier).onGameStart();
          break;

        // Un jugador se desconectó antes de que empezara la partida.
        // Payload: { message: String }
        case 'player_disconnected':
          final String msg = decoded['message'] as String? ?? '';
          _ref.read(lobbyProvider.notifier).onPlayerDisconnected(msg);
          break;

        // Este dispositivo ha sido reemplazado por otro del mismo usuario.
        // Payload: { message: String }
        case 'force_disconnect':
          final String msg = decoded['message'] as String? ?? '';
          _ref.read(lobbyProvider.notifier).onForceDisconnect(msg);
          disconnect();
          break;

        // El usuario se ha reconectado a una partida en curso desde otro dispositivo.
        // Payload: { game_status: 'WAITING'|'PLAYING', current_board: Map }
        case 'reconnect_success':
          final String status = decoded['game_status'] as String? ?? 'WAITING';
          _ref
              .read(lobbyProvider.notifier)
              .onReconnectSuccess(status, decoded['current_board']);
          break;

        // Mensaje no relevante para el lobby (corresponde a la fase de juego).
        default:
          print('LobbyWebSocket: mensaje ignorado en lobby → ${decoded['type']}');
      }
    } catch (e) {
      print('LobbyWebSocket: error decodificando mensaje → $e');
    }
  }

  // Cierra la conexión WebSocket del lobby.
  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }
}
