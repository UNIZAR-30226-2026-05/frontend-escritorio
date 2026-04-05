import 'dart:convert';
import '../../../core/constants/api_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../board/presentation/controllers/game_provider.dart';
import '../domain/gamemodels.dart';
import '../../auth/presentation/controllers/auth_provider.dart';
import '../../shop/data/shop_repository.dart';

// Este Provider nos permite acceder al WebSocketService en toda la app de forma segura
final webSocketProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(ref);
});

class WebSocketService {
  final Ref _ref;
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isActionLocked = false;
  // Indica que este jugador ya envió end_round y espera la señal del fin de ronda.
  // El backend, al recibir todos los end_round, manda balances_changed a todos.
  // Eso es cuando activamos el overlay de espera del Videojugador para todos.
  bool _localPlayerSentEndRound = false;

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
        // Tipo de mensaje de movimiento de jugador (tras tirar dados)
        case 'player_moved':
          // El backend nos informa que alguien ha tirado el dado y se ha movido
          final String userId = decoded['user'];
          final int newTile = decoded['nueva_casilla'];
          // El backend envía dado1 y dado2 por separado, los sumamos
          final int dado1 = decoded['dado1'] ?? 0;
          final int dado2 = decoded['dado2'] ?? 0;
          final int diceTotal = dado1 + dado2;

          // DEBUG: Imprimir exactamente qué recibió del backend
          print('═══════════════════════════════════════════');
          print(' PLAYER_MOVED recibido del backend:');
          print('  • User ID: $userId');
          print('  • Dado 1: $dado1');
          print('  • Dado 2: $dado2');
          if (diceTotal != 0) {
            print('  • Total dado: $diceTotal');
          }
          print('  • Nueva casilla (backend): $newTile');
          print('═══════════════════════════════════════════');

          // Usar Riverpod para enviar los datos al gameProvider
          _ref
              .read(gameProvider.notifier)
              .updatePlayerFromBackend(userId, newTile, diceTotal,
                  dice1: dado1, dice2: dado2)
              .then((_) {
            // Para evitar que cuente como turno los movimientos de avanzar y retroceder por casillas
            Future.delayed(const Duration(milliseconds: 100), () {
              // Solo avisamos al backend si no quedan animaciones pendientes
              final isQueueEmpty =
                  _ref.read(gameProvider.notifier).isAnimationQueueEmpty;
              final gameState = _ref.read(gameProvider);

              final myUsername = _ref.read(authProvider).username;

              // Comparamos el userId del backend con nuestro username
              if (isQueueEmpty &&
                  gameState.currentPhase != GamePhase.finished &&
                  userId == myUsername) {
                _sendEndRound();
              }
            });
          });
          break;

        // Tipo de mensaje de reconexión exitosa (o nueva conexión en la que ya había datos)
        case 'reconnect_success':
          print("Reconexión exitosa. Sincronizando tablero...");
          final String gameStatus = decoded['game_status'] ?? 'WAITING';
          final Map<String, dynamic> currentBoard =
              decoded['current_board'] ?? {};

          _ref
              .read(gameProvider.notifier)
              .syncBoardState(currentBoard, gameStatus);
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

        // Tipo de mensaje sobre en qué tipo de casilla ha caído el jugador
        case 'tipo_casilla':
          print(
              "El jugador ha caído en una casilla de tipo: \${decoded['casilla']}");
          // TODO: Mostrar algún tipo de feedback en la UI (ej. animación u objeto obtenido)
          break;

        // Tipo de mensaje cuando el jugador cae en una casilla de objeto y le toca intercambiar
        case 'intercambiar_objeto':
          print(
              "Debes elegir un jugador para intercambiar un objeto: \${decoded['message']}");
          // TODO: Abrir un modal en la UI para elegir al jugador
          break;

        // Tipo de mensaje de inicio de minijuego
        case 'ini_minijuego':
          print("Minijuego iniciado.");
          _localPlayerSentEndRound = false; // Nueva ronda: resetear bandera
          final String? name = decoded['minijuego'];
          final String? desc = decoded['descripcion'];
          final Map<String, dynamic>? details = decoded['detalles'] != null
              ? Map<String, dynamic>.from(decoded['detalles'])
              : null;
          if (name != null) {
            _ref.read(gameProvider.notifier).startMinigame(
                  name: name,
                  description: desc,
                  details: details,
                );
          }
          break;

        // Tipo de mensaje de resultados de minijuego
        case 'minijuego_resultados':
          // El backend envía "nuevo_orden" como un Map {jugador: posicion},
          // NO como una lista "order". Ordenamos por valor ascendente para
          // reconstruir el turno correcto: posicion 1 primero, 4 último.
          final Map<String, dynamic> rawOrder =
              Map<String, dynamic>.from(decoded['nuevo_orden'] ?? {});
          final order = rawOrder.entries.toList()
            ..sort((a, b) => (a.value as int).compareTo(b.value as int));
          final turnOrder = order.map((e) => e.key).toList();

          final results = decoded['resultados'] != null
              ? Map<String, dynamic>.from(decoded['resultados'])
              : null;
          if (results != null) {
            _ref
                .read(gameProvider.notifier)
                .setMinigameResults(results, turnOrder);
          }
          break;

        // Tipo de mensaje para actualizar inventario
        case 'inventory_updated':
          final userId = decoded['user'];
          final stringList = List<String>.from(decoded['inventario_actual']);

          // Mapeamos los strings del back a tus ItemType
          final enumList = stringList
              .map((str) => ShopRepository.parseItemType(str))
              .toList();

          _ref
              .read(gameProvider.notifier)
              .updateInventoryAndBalance(userId, newInventory: enumList);
          break;

        // Tipo de mensaje para actualizar balances (monedas)
        case 'balances_changed':
          final balances = decoded['balances'] as Map<String, dynamic>;
          balances.forEach((userId, coins) {
            _ref
                .read(gameProvider.notifier)
                .updateInventoryAndBalance(userId, newBalance: coins as int);
          });
          // Si este jugador ya terminó su ronda y el backend manda el balance
          // de fin de ronda (ocurre cuando TODOS los jugadores han terminado),
          // mostramos la pantalla de espera del Videojugador para todos.
          // Solo disparamos si activePlayerIndex es 0 (vuelta al inicio),
          // indicando que el último jugador ya sumó su movimiento.
          if (_localPlayerSentEndRound &&
              _ref.read(gameProvider).activePlayerIndex == 0) {
            _localPlayerSentEndRound = false;
            _ref.read(gameProvider.notifier).setWaitingForMinigameChoice(true);
          }
          break;

        case 'choose_minijuego':
          print("El backend pide elegir minijuego.");
          // Forzamos Reflejos como nos han pedido
          _ref
              .read(gameProvider.notifier)
              .setMinigameChoices(['Reflejos', 'Reflejos']);
          break;

        // Tipo de mensaje por defecto
        default:
          if (decoded.containsKey('error')) {
            print('Error desde el backend: ${decoded['error']}');
            _isActionLocked = false; // Liberamos acción en caso de error
          } else {
            print('Mensaje WebSocket parseado, pero no manejado: $decoded');
          }
      }

      // Capturamos también errores directos si vienen fuera de type
      if (decoded.containsKey('error') && decoded['type'] == null) {
        print('Error desde el backend: ${decoded['error']}');
        _isActionLocked = false;
      }
    } catch (e) {
      print('Error decodificando el mensaje de WebSocket: $e');
    }
  }

  // Función que manda la acción de mover jugador (tirar dados) al backend
  void rollDiceCommand(String gameId, String userId) {
    // Solo manda si el canal existe y está conectado
    if (_channel != null && _isConnected) {
      // PARA QUE NO HAYA DOBLES CLICS
      if (_isActionLocked) return; // SI ESTÁ BLOQUEADO, IGNORAR CLIC
      _isActionLocked = true;

      // Crear paquete con la acción move_player (el backend calcula los dados)
      final payload = {'action': 'move_player', 'payload': {}};
      // Mandar el paquete codificado al back
      _channel!.sink.add(jsonEncode(payload));
    } else {
      print("No se pudo enviar 'move_player' porque no hay conexión.");
    }
  }

  void _sendEndRound() {
    if (_channel != null && _isConnected) {
      final payload = {'action': 'end_round', 'payload': {}};
      print(' Enviando END_ROUND al backend');
      _channel!.sink.add(jsonEncode(payload));

      _isActionLocked = false; // LIBERA EL DADO PARA EL PRÓXIMO TURNO
      // Marcamos que este jugador terminó su turno. La pantalla de espera
      // se activará en 'balances_changed', que llega cuando TODOS han terminado.
      _localPlayerSentEndRound = true;
    }
  }

  void sendMinigameScore(int score) {
    if (_channel != null && _isConnected) {
      final payload = {
        'action': 'score_minijuego',
        'payload': {'score': score}
      };
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void sendMinigameChoice(String minigameName) {
    if (_channel != null && _isConnected) {
      final payload = {
        'action': 'ini_round',
        'payload': {
          'minijuego': minigameName,
          'descripcion': '¿Ser rapido es tu virtud?'
        }
      };
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }

  void endRound(String gameId) {
    if (_channel != null && _isConnected) {
      final payload = {'action': 'end_round', 'payload': {}};
      _channel!.sink.add(jsonEncode(payload));
    }
  }

  // Método para enviar acciones genéricas al backend (como compras o uso de objetos)
  void sendGenericAction(Map<String, dynamic> payload) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(payload));
    } else {
      print("No se pudo enviar la acción porque no hay conexión.");
    }
  }
}
