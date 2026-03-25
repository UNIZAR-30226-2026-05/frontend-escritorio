import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../board/presentation/controllers/game_provider.dart';

// Este Provider nos permite acceder al WebSocketService en toda la app de forma segura
final webSocketProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(ref);
});

class WebSocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  bool _isConnected = false;

  WebSocketService(this._ref);

  // Función para conectar con el backend a través de websockets
  void connect(String gameId, String token) {
    // Si ya está conectado no se hace nada
    if (_isConnected) return;

    final url = '${ApiConstants.wsBaseUrl}/ws/partida/$gameId?token=$token';

    // Se intenta conectar a través de la url de arriba y oir los mensajes
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          // Distingue entre los tipos de mensajes que pueden llegar
          _handleIncomingMessage(message.toString());
        },
        // Se ejecuta si la conexión se cierra limpiamente
        onDone: () {
          _isConnected = false;
          print('WebSocket connection closed.');
        },
        // Se ejecuta si la conexión se cierra con errores
        onError: (error) {
          _isConnected = false;
          print('WebSocket Error: $error');
        },
      );
    } catch (e) {
      _isConnected = false;
      print('Error al conectar con WebSocket: $e');
    }
  }

  // Función que distingue entre los tipos de mensajes que pueden llegar
  void _handleIncomingMessage(String message) {
    try {
      final decoded = jsonDecode(message) as Map<String, dynamic>;

      switch (decoded['type']) {
        // Tipo de mensaje de tirar los dados
        case 'rolled_dice':
          // El backend nos informa que alguien ha tirado el dado y se ha movido
          final String userId = decoded['user'];
          final int result = decoded['result'];
          final int newTile = decoded['nueva_casilla'];

          // Usar Riverpod para enviar los datos al gameProvider
          _ref
              .read(gameProvider.notifier)
              .updatePlayerFromBackend(userId, newTile, result);
          break;

        // Tipo de mensaje de comenzar el juego
        case 'game_start':
          print("El juego ha iniciado.");
          // TODO Cambiar a GamePhase.playing cuando se soporte
          break;

        // Tipo de mensaje de actualizar el lobby
        case 'lobby_update':
          print("Lobby update: \${decoded['message']}");
          // TODO Updatear cuando se soporte
          break;

        // Tipo de mensaje de que se ha desconectado un jugador
        case 'player_disconnected':
          print("Jugador desconectado: \${decoded['message']}");
          // TODO Realizar acción pertinente cuando se soporte
          break;

        // Tipo de mensaje por defecto
        default:
          print('Mensaje WebSocket parseado, pero no manejado: $decoded');
      }
    } catch (e) {
      print('Error decodificando el mensaje de WebSocket: $e');
    }
  }

  // TODO Modificar la función para que funcione con el backend
  // Función que manda mensajes a la api a través del canal
  //
  void rollDiceCommand(String gameId, String userId) {
    // Solo manda si el canal existe y está conectado
    if (_channel != null && _isConnected) {
      // Crear paquete con la acción de tirar dado
      final payload = {'action': 'tirar_dado', 'payload': {}};
      // Mandar el paquete codificado al back
      _channel!.sink.add(jsonEncode(payload));
    } else {
      print("No se pudo enviar 'tirar_dado' porque no hay conexión.");
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }
}
