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

// Definicion de la clase WebSocketService, que se encarga 
// de gestionar la conexión WebSocket con el backend
class WebSocketService {
  // Referencia a Ref para poder acceder a otros providers (como gameProvider)
  final Ref _ref;
  // Canal de comunicación WebSocket con el backend
  WebSocketChannel? _channel;
  // Booleanos auxiliares para controlar el estado de la conexión y evitar acciones repetidas
  bool _isConnected = false;
  bool _isActionLocked = false;
  // Indica que este jugador ya envió end_round y espera la señal del fin de ronda.
  // El backend, al recibir todos los end_round, manda balances_changed a todos.
  // Eso es cuando activamos el overlay de espera del Videojugador para todos.
  bool _localPlayerSentEndRound = false;

  // Constructor que recibe Ref para poder usar otros providers dentro de esta clase
  WebSocketService(this._ref);

  // Función para conectar con el backend a través de websockets
  void connect(String gameId, String token) {
    // Si ya está conectado no se hace nada
    if (_isConnected) return;

    // Construimos la url de conexión usando el gameId y el token de autenticación
    final url = '${ApiConstants.wsBaseUrl}/ws/partida/$gameId?token=$token';

    // Se intenta conectar a través de la url de arriba y oir los mensajes
    try {
      // Conectamos al WebSocket del backend usando la url construida
      _channel = WebSocketChannel.connect(Uri.parse(url));
      // Si la conexión es exitosa, marcamos que estamos conectados
      _isConnected = true;

      // Escuchamos los mensajes que llegan del backend a través del canal
      // El "!" significa que asumimos que _channel no es null en este punto, 
      // porque si la conexión falla se lanza una excepción y no se llega aquí.
      _channel!.stream.listen(
        // Cuando llega un mensaje, se ejecuta esta función con el mensaje recibido
        (message) {
          // Distingue entre los tipos de mensajes que pueden llegar
          // Implementado mas abajo
          _handleIncomingMessage(message.toString());
        },
        // Se ejecuta si la conexión se cierra limpiamente
        onDone: () {
          // Si el canal se cierra, marcamos que no estamos conectados
          _isConnected = false;
          print('WebSocket connection closed.');
        },
        // Se ejecuta si la conexión se cierra con errores
        onError: (error) {
          // Si hay un error en la conexión, marcamos que no estamos conectados
          _isConnected = false;
          print('WebSocket Error: $error');
        },
      );
    // Si ocurre cualquier error al intentar conectar, se captura aquí
    } catch (e) {
      // Si hay un error al conectar, marcamos que no estamos conectados y mostramos el error
      _isConnected = false;
      print('Error al conectar con WebSocket: $e');
    }
  }

  // Función privada para manejar los mensajes que llegan del backend a través del WebSocket
  void _handleIncomingMessage(String message) {
    try {
      // Intentamos decodificar el mensaje JSON que llega del backend
      final decoded = jsonDecode(message) as Map<String, dynamic>;

      // En funccion del mensaje que llega, se ejecutan diferentes acciones.
      // Claves presentes en la documentacion de los WS.
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
              .read(gameProvider.notifier)    // Accedemos al notifier para poder llamar a métodos que actualizan el estado
              .updatePlayerFromBackend(userId, newTile, diceTotal,
                  dice1: dado1, dice2: dado2) // Llamamos al método que actualiza la posición del jugador en el estado del juego
              .then((_) {
            // Para evitar que cuente como turno los movimientos de avanzar y retroceder por casillas
            Future.delayed(const Duration(milliseconds: 100), () {
              // Solo avisamos al backend si no quedan animaciones pendientes
              final isQueueEmpty = _ref.read(gameProvider.notifier).isAnimationQueueEmpty;
              // Leemos el estado actual del juego para saber en qué fase estamos
              final gameState = _ref.read(gameProvider);
              // Leemos nuestro username para compararlo con el userId del backend
              final myUsername = _ref.read(authProvider).username;

              // SI NO QUEDAN ANIMACIONES PENDIENTES, NO ESTAMOS EN LA FASE DE FIN DE JUEGO, Y EL MOVIMIENTO LO HIZO ESTE JUGADOR, 
              // ENVIAMOS END_ROUND
              if (isQueueEmpty && gameState.currentPhase != GamePhase.finished && userId == myUsername) {
                _sendEndRound();
              }
            });
          });
          break;

        // Tipo de mensaje de reconexión exitosa
        case 'reconnect_success':
          // DEBUG: imprimimos reconexion exitosa 
          print("Reconexión exitosa. Sincronizando tablero...");
          // La reconexion es exitosa y guardamos el estado de playing
          final String gameStatus = decoded['game_status'] ?? 'PLAYING';
          // El backend envía el estado completo del tablero en "current_board" para que el cliente se sincronice
          final Map<String, dynamic> currentBoard = decoded['current_board'] ?? {};
          // Enviamos el estado del tablero al gameProvider para que actualice su estado interno y la UI se sincronice con el backend
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
          // DEBUG: imprimimos que llego el mensaje de inicio de minijuego
          print("Minijuego iniciado.");
          // Cuando empieza el minijuego podemos reiniciar el flag de end_round
          _localPlayerSentEndRound = false; 
          // Guardamos el nombre del minijuego, su descripción y detalles adicionales (si los hay)
          final String? name = decoded['minijuego'];
          final String? desc = decoded['descripcion'];
          final Map<String, dynamic>? details = decoded['detalles'] != null
              ? Map<String, dynamic>.from(decoded['detalles'])
              : null;
          // Mandamos el nombre del minijuego al gameProvider para que actualice su estado y muestre el overlay correspondiente. 
          // Si el backend no envía un nombre, no hacemos nada.
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
          final Map<String, dynamic> rawOrder = Map<String, dynamic>.from(decoded['nuevo_orden'] ?? {});
          // AQUI ORDENAMOS EL MAP POR VALOR Y EXTRAEMOS SOLO LOS NOMBRES DE LOS JUGADORES EN ORDEN
          final order = rawOrder.entries.toList()
            ..sort((a, b) => (a.value as int).compareTo(b.value as int));
          final turnOrder = order.map((e) => e.key).toList();

          // El backend envía "resultados" como un Map {jugador: resultado}, que puede ser la puntuación o simplemente 
          // "ganador"/"perdedor" dependiendo del minijuego.
          final results = decoded['resultados'] != null
              ? Map<String, dynamic>.from(decoded['resultados'])
              : null;
          // Mandamos el orden de turno y los resultados al gameProvider para que actualice su estado y 
          // muestre la pantalla de resultados del minijuego.
          if (results != null) {
            _ref
                .read(gameProvider.notifier)
                .setMinigameResults(results, turnOrder);
          }
          break;

        // Tipo de mensaje para actualizar inventario
        case 'inventory_updated':
          // Extraemos el userId y la lista de strings del inventario actual que envía el backend
          final userId = decoded['user'];
          final stringList = List<String>.from(decoded['inventario_actual']);

          // Mapeamos los strings del back a tus ItemType
          final enumList = stringList
              .map((str) => ShopRepository.parseItemType(str))
              .toList();

          // Acrualizamos el inventario del jugador correspondiente en el gameProvider
          _ref
              .read(gameProvider.notifier)
              .updateInventoryAndBalance(userId, newInventory: enumList);
          break;

        // Tipo de mensaje para actualizar balances (monedas que gana/pierde cada jugador)
        case 'balances_changed':
          // Nos llega un Map con el balance actualizado de cada jugador, por ejemplo: {"player1": 150, "player2": 50}
          final balances = decoded['balances'] as Map<String, dynamic>;
          // Para cada jugador en el Map, actualizamos su balance en el gameProvider
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

        // Tipo de mensaje para elegir minijuego 
        case 'choose_minijuego':
          print("El backend pide elegir minijuego.");
          // HARDCODEADO PARA FORZAR REFLEJOS Y TREN (MINIJUEGOS IMPLMENTADOS)
          _ref
              .read(gameProvider.notifier)
              .setMinigameChoices(['Reflejos', 'Tren']);
          break;

        // Tipo de mensaje por defecto
        default:
          // Si el mensaje tiene una clave "error""
          if (decoded.containsKey('error')) {
            // Iprimimos el error y liberamos la acción
            print('Error desde el backend: ${decoded['error']}');
            _isActionLocked = false;
          } else {
            print('Mensaje WebSocket parseado, pero no manejado: $decoded');
          }
      }

      // Capturamos también errores directos si vienen fuera de type
      if (decoded.containsKey('error') && decoded['type'] == null) {
        // Mismo procedimiento que antes
        print('Error desde el backend: ${decoded['error']}');
        _isActionLocked = false;
      }
      // Capturamos cualquier otro error que pueda ocurrir al decodificar o manejar el mensaje
    } catch (e) {
      print('Error decodificando el mensaje de WebSocket: $e');
    }
  }

  // Función publica que manda la acción de mover jugador (tirar dados) al backend
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
    // Si no hay conexion imrpimimos un msj de error
    } else {
      print("No se pudo enviar 'move_player' porque no hay conexión.");
    }
  }

  // Función privada para mandar la acción de fin de ronda al backend
  void _sendEndRound() {
    // Comprobamos previamente que el canal existe y está conectado antes de mandar la acción
    if (_channel != null && _isConnected) {
      // Creamos el payload como se especifica en la domuentacion de los WS
      final payload = {'action': 'end_round', 'payload': {}};
      // DEBUG: guarda que imprimmos para comprobar que se manda correctamente
      print(' Enviando END_ROUND al backend');
      // Mandamos el paquete codificado al backend.
      _channel!.sink.add(jsonEncode(payload));

      _isActionLocked = false; // LIBERA EL DADO PARA EL PRÓXIMO TURNO
      // Marcamos que este jugador terminó su turno. La pantalla de espera
      // se activará en 'balances_changed', que llega cuando TODOS han terminado.
      _localPlayerSentEndRound = true;
    // Si no hay conexion imrpimimos un msj de error
    } else {
      print("No se pudo enviar 'end_round' porque no hay conexión.");
    }
  }

  // Funcion publica para enviar la puntuación de un minijuego al backend.
  // Se hace para aquellos minijuegos que requieren enviar la puntuación (como Reflejos o Tren).
  void sendMinigameScore(int score, {int? objetivo}) {
    // Solo manda si el canal existe y está conectado
    if (_channel != null && _isConnected) {
      // Creamos inner para el payload con la puntuación.
      final Map<String, dynamic> inner = {'score': score};
      // Si se proporciona un objetivo, lo añadimos al payload.
      if (objetivo != null) inner['objetivo'] = objetivo;
      // Creamos el payload completo con la acción 'score_minijuego' y el inner con la puntuación.
      final payload = {'action': 'score_minijuego', 'payload': inner};
      // Mandamos el paquete codificado al backend.
      _channel!.sink.add(jsonEncode(payload));
    // Si no hay conexion imrpimimos un msj de error
    } else {
      print("No se pudo enviar 'score_minijuego' porque no hay conexión.");
    }
  }

  // Funcion pública para enviar la elección de minijuego al backend. 
  // Se llama cuando el videojugador elige un minijuego.
  void sendMinigameChoice(String minigameName) {
    if (_channel != null && _isConnected) {
      // creamos el payload como se especifica en la docuemntacion de los WS
      final payload = {
        'action': 'ini_round',
        'payload': {
          'minijuego': minigameName,
          // MENSAJE HARCODEADO PARA FORZAR REFLEJOS Y TREN (MINIJUEGOS IMPLMENTADOS)
          'descripcion': '¿Ser rapido es tu virtud?'
        }
      };
      // Enviamos el paquete codificado al backend.
      _channel!.sink.add(jsonEncode(payload));
    // Si no hay conexion imrpimimos un msj de error
    } else {
      print("No se pudo enviar 'ini_round' porque no hay conexión.");
    }
  }

  // Función pública para desconectar el WebSocket cuando ya no se necesite
  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
  }

  // Funcion publica para enviar acciones genéricas al backend (como compras o uso de objetos)
  void sendGenericAction(Map<String, dynamic> payload) {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode(payload));
    // Si no hay conexion imrpimimos un msj de error
    } else {
      print("No se pudo enviar la acción porque no hay conexión.");
    }
  }
}
