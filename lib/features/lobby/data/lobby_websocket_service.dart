import 'dart:async';
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
// Este servicio se usa mientras se espera a los 4 jugadores.
// Cuando recibe 'game_start' cierra su escucha y la UI navega al tablero,
// donde el WebSocketService de board abrirá su propia conexión.
class LobbyWebSocketService {
  // Referencia a Ref para acceder a otros providers.
  final Ref _ref;
  // Canal WebSocket para la conexión del lobby.
  WebSocketChannel? _channel;
  // Flag para evitar reconexiones múltiples.
  bool _isConnected = false;
  // Game id de la partida a la que se está intentando conectar.
  String? _pendingGameId;

  // Datos guardados para poder reconectar si se cae la conexión.
  String? _savedGameId;
  String? _savedToken;
  // True cuando el cierre del WS fue intencionado (logout, abandonar, etc.).
  // False cuando se cae solo: en ese caso se reintenta la conexión.
  bool _intentionalDisconnect = false;
  // Número de intentos de reconexión consecutivos.
  int _reconnectAttempts = 0;
  // Máximo de reintentos antes de desistir.
  static const int _maxReconnectAttempts = 5;
  // Timer que lanza el siguiente intento de reconexión.
  Timer? _reconnectTimer;

  // Constructor que recibe Ref para poder interactuar con el estado del lobby.
  LobbyWebSocketService(this._ref);

  // Metodo público para conectar al WebSocket del lobby usando el gameId y token.
  // Conecta al WebSocket de la partida en fase de lobby.
  void connect(String gameId, String token) {
    // Si ya está conectado no se hace nada.
    if (_isConnected) return;

    // Guarda credenciales para poder reconectar si se pierde la conexión.
    _savedGameId = gameId;
    _savedToken = token;
    _intentionalDisconnect = false;

    // Guarda el gameId pendiente hasta que el backend confirme con lobby_update.
    _pendingGameId = gameId;
    // Construye la URL del WebSocket usando el gameId y token.
    final url = ApiConstants.wsPartidaUrl(gameId, token);

    // Intenta conectar al WebSocket y configurar los listeners para mensajes, cierre y errores.
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;

      // El ¨!¨ asegura al compilador que _channel no es null en este punto,
      // ya que si la conexión falla se lanza una excepción y no se llega aquí.
      // Listener para mensajes entrantes del WebSocket.
      _channel!.stream.listen(
        (message) {
          _handleIncomingMessage(message.toString());
        },
        // Se ejecuta si la conexión se cierra limpiamente.
        onDone: () {
          _isConnected = false;
          // Solo reintenta si el cierre no fue intencionado.
          if (!_intentionalDisconnect) {
            _scheduleReconnect();
          }
        },
        // Se ejecuta si la conexión se cierra con error (p.ej. partida no encontrada).
        onError: (error) {
          _isConnected = false;
          if (_intentionalDisconnect) return;
          // Si aún no había confirmado el gameId, es un error de conexión inicial.
          if (_pendingGameId != null) {
            _pendingGameId = null;
            _ref.read(lobbyProvider.notifier).onWsError('No se pudo conectar a la partida');
          } else {
            _scheduleReconnect();
          }
        },
      );
    // Si hay un error al intentar conectar, se captura la excepción, se marca como no conectado y se imprime el error.
    } catch (e) {
      _isConnected = false;
      if (!_intentionalDisconnect && _pendingGameId == null) {
        _scheduleReconnect();
      } else {
        _pendingGameId = null;
        _ref.read(lobbyProvider.notifier).onWsError('No se pudo conectar a la partida');
      }
    }
  }

  // Programa un reintento de conexión con retardo exponencial.
  // Máximo _maxReconnectAttempts intentos antes de notificar al usuario.
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _ref.read(lobbyProvider.notifier).onWsError('Se perdió la conexión con la partida');
      return;
    }
    // Retardo exponencial: 2s, 4s, 8s, 16s, 32s.
    final delay = Duration(seconds: 2 << _reconnectAttempts);
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () {
      if (!_intentionalDisconnect && _savedGameId != null && _savedToken != null) {
        connect(_savedGameId!, _savedToken!);
      }
    });
  }

  // Procesa los mensajes entrantes del backend durante la fase de lobby.
  void _handleIncomingMessage(String message) {
    try {
      final decoded = jsonDecode(message) as Map<String, dynamic>;

      // Comprueba primero si el mensaje es un error genérico del backend.
      // Si el mensaje contiene una clave 'error', se asume que es un error genérico y se maneja con onWsError.
      if (decoded.containsKey('error')) {
        _ref.read(lobbyProvider.notifier).onWsError(decoded['error'] as String);
        // La conexión no es válida (partida llena, no encontrada, etc.): desconectar.
        disconnect();
        return;
      }

      // Si no es un error genérico, se procesa según el tipo de mensaje.
      switch (decoded['type'] as String?) {
        // El backend notifica cuántos jugadores están conectados a la partida.
        case 'lobby_update':
          final List<String> players =(decoded['players_connected'] as List<dynamic>? ?? []).map((p) => p as String).toList();
          final String msg = decoded['message'] as String? ?? '';
          // Confirma el gameId en el estado solo cuando el backend responde correctamente.
          if (_pendingGameId != null) {
            _ref.read(lobbyProvider.notifier).unirseAPartida(_pendingGameId!);
            _pendingGameId = null;
          }
          // Conexión confirmada: resetea el contador de reintentos.
          _reconnectAttempts = 0;
          _ref.read(lobbyProvider.notifier).onLobbyUpdate(players, msg);
          break;

        // Los 4 jugadores se han conectado: empieza la selección de personaje.
        case 'game_start':
          _ref.read(lobbyProvider.notifier).onGameStart();
          break;

        // Un jugador se desconectó antes de que empezara la partida.
        case 'player_disconnected':
          final List<String> players =(decoded['players_connected'] as List<dynamic>? ?? []).map((p) => p as String).toList();
          final String msg = decoded['message'] as String? ?? '';
          _ref.read(lobbyProvider.notifier).onPlayerDisconnected(players, msg);
          break;

        // Este dispositivo ha sido reemplazado por otro del mismo usuario.
        case 'force_disconnect':
          final String msg = decoded['message'] as String? ?? '';
          _ref.read(lobbyProvider.notifier).onForceDisconnect(msg);
          disconnect();
          break;

        // El usuario se ha reconectado a una partida desde otro dispositivo.
        // Solo nos interesa si la partida sigue en WAITING (sigue en lobby).
        // Si es PLAYING, el board se encargará cuando abra su propio WebSocket.
        case 'reconnect_success':
          final String status = decoded['game_status'] as String? ?? 'WAITING';
          if (status == 'WAITING') {
            _reconnectAttempts = 0;
            _ref.read(lobbyProvider.notifier).onReconnectSuccess(decoded['current_board']);
          }
          break;

        // Mensaje no relevante para el lobby (corresponde a la fase de juego).
        default:
          break;
      }
    } catch (e) {
      // Error decodificando el mensaje, se ignora.
    }
  }

  // Cierra la conexión WebSocket del lobby de forma intencionada.
  void disconnect() {
    // Marca el cierre como intencionado para no intentar reconectar.
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _channel?.sink.close();
    _isConnected = false;
    _pendingGameId = null;
    _savedGameId = null;
    _savedToken = null;
  }
}
