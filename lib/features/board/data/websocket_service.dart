import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../core/constants/api_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../board/presentation/controllers/game_provider.dart';
import 'dart:async';
import '../domain/gamemodels.dart';
import '../../auth/presentation/controllers/auth_provider.dart';
import '../../shop/data/shop_repository.dart';

// Este Provider nos permite acceder al WebSocketService en toda la app de forma segura
final webSocketProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService(ref);
  // Nos aseguramos de que el socket se cierre cuando el provider se destruya
  ref.onDispose(() => service.disconnect());
  return service;
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

  // Cuando el jugador activo ha hecho su tirada principal
  bool _pendingTurnAdvance = false;

  // Controlador para notificar eventos especiales a la UI (ej. navegación forzada)
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  // Constructor que recibe Ref para poder usar otros providers dentro de esta clase
  WebSocketService(this._ref);

  // Función para conectar con el backend a través de websockets
  void connect(String gameId, String token) {
    // Si ya está conectado no se hace nada
    if (_isConnected) return;

    // Construimos la url de conexión usando el gameId y el token de autenticación
    final url = ApiConstants.wsPartidaUrl(gameId, token);

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
          debugPrint('WebSocket connection closed.');
        },
        // Se ejecuta si la conexión se cierra con errores
        onError: (error) {
          // Si hay un error en la conexión, marcamos que no estamos conectados
          _isConnected = false;
          debugPrint('WebSocket Error: $error');
        },
      );
      // Si ocurre cualquier error al intentar conectar, se captura aquí
    } catch (e) {
      // Si hay un error al conectar, marcamos que no estamos conectados y mostramos el error
      _isConnected = false;
      debugPrint('Error al conectar con WebSocket: $e');
    }
  }

  // Función privada para manejar los mensajes que llegan del backend a través del WebSocket
  Future<void> _handleIncomingMessage(String message) async {
    try {
      // Intentamos decodificar el mensaje JSON que llega del backend
      final decoded = jsonDecode(message) as Map<String, dynamic>;

      // En funccion del mensaje que llega, se ejecutan diferentes acciones.
      // Claves presentes en la documentacion de los WS.
      switch (decoded['type']) {
        // Tipo de mensaje de movimiento de jugador (tras tirar dados)
        case 'player_moved':
          final String userId = decoded['user'];
          _ref.read(gameProvider.notifier).clearBlockingTurnPlayer();
          final int newTile = decoded['nueva_casilla'];
          final int dado1 = decoded['dado1'] ?? 0;
          final int dado2 = decoded['dado2'] ?? 0;
          final int diceTotal = dado1 + dado2;

          // DEBUG: Imprimir exactamente qué recibió del backend
          debugPrint('═══════════════════════════════════════════');
          debugPrint(' PLAYER_MOVED recibido del backend:');
          debugPrint('  • User ID: $userId');
          debugPrint('  • Dado 1: $dado1');
          debugPrint('  • Dado 2: $dado2');
          if (diceTotal != 0) {
            debugPrint('  • Total dado: $diceTotal');
          }
          debugPrint('  • Nueva casilla (backend): $newTile');
          debugPrint('═══════════════════════════════════════════');

          // Si el total es > 0 es que ha tirado dados de movimiento,
          // marcamos que tiene pendiente avanzar el turno.
          if (diceTotal > 0) {
            _pendingTurnAdvance = true;
          }
          // El wait de la ruleta lo manejaremos directamente en la cola de animación
          _ref
              .read(gameProvider.notifier)
              .updatePlayerFromBackend(userId, newTile, diceTotal,
                  dice1: dado1, dice2: dado2)
              .then((_) {
            // Llamamos al evaluador SIN ARGUMENTOS
            checkAndFinalizeTurn();
          });
          break;

        // Tipo de mensaje de reconexión exitosa
        case 'reconnect_success':
          // DEBUG: imprimimos reconexion exitosa
          debugPrint("Reconexión exitosa. Sincronizando tablero...");
          // La reconexion es exitosa y guardamos el estado de playing
          final String gameStatus = decoded['game_status'] ?? 'PLAYING';
          // El backend envía el estado completo del tablero en "current_board" para que el cliente se sincronice
          final Map<String, dynamic> currentBoard =
              decoded['current_board'] ?? {};
          // Enviamos el estado del tablero al gameProvider para que actualice su estado interno y la UI se sincronice con el backend
          _ref
              .read(gameProvider.notifier)
              .syncBoardState(currentBoard, gameStatus);
          break;

        // Tipo de mensaje de comenzar el juego
        case 'game_start':
          debugPrint("El juego ha iniciado.");
          // TODO Cambiar a GamePhase.playing cuando se soporte
          break;

        // Tipo de mensaje de actualizar el lobby
        case 'lobby_update':
          debugPrint("Lobby update: \${decoded['message']}");
          // TODO Updatear cuando se soporte
          break;

        // Tipo de mensaje de que se ha desconectado un jugador
        case 'player_disconnected':
          debugPrint("Jugador desconectado: \${decoded['message']}");
          final String discPlayer = decoded['player'] ?? '';
          if (discPlayer.isNotEmpty) {
            _ref
                .read(gameProvider.notifier)
                .setPlayerConnectionStatus(discPlayer, false);
          }
          break;

        case 'not_playing':
          final String notPlayingPlayer = decoded['player'] ?? '';
          if (notPlayingPlayer.isNotEmpty) {
            _ref
                .read(gameProvider.notifier)
                .setPlayerConnectionStatus(notPlayingPlayer, false);
          }
          break;

        // Tipo de mensaje sobre en qué tipo de casilla ha caído el jugador
        case 'tipo_casilla':
          final tipoCasilla = decoded['casilla'] as String? ?? '';
          debugPrint(
              "El jugador ha caído en una casilla de tipo: $tipoCasilla");
          // Si es una casilla especial (extra, obj = ruleta, mini = minijuego individual),
          // el jugador activo va a entrar en un evento bloqueante.
          // Lo guardamos para que los demás clientes no muestren el botón de dados.
          if (tipoCasilla == 'extra' || tipoCasilla == 'obj') {
            final gameState = _ref.read(gameProvider);
            final activePlayerIdx = gameState.activePlayerIndex;
            if (activePlayerIdx >= 0 &&
                activePlayerIdx < gameState.turnOrder.length) {
              final blockingId = gameState.turnOrder[activePlayerIdx];
              _ref
                  .read(gameProvider.notifier)
                  .setBlockingTurnPlayer(blockingId);
            }
          }
          break;

        case 'fin_partida':
          final String winner = decoded['winner'] ?? 'Desconocido';
          debugPrint(
              '¡FIN DE PARTIDA! El jugador $winner ha llegado a la meta.');
          // El cambio a GamePhase.finished lo maneja el game_provider
          // automáticamente cuando la animación del jugador alcanza la casilla final.
          break;

        // Tipo de mensaje cuando el jugador cae en una casilla de objeto y le toca intercambiar
        case 'intercambiar_objeto':
          debugPrint("Ignorado: Intercambiar objeto delegado");
          break;

        case 'dice_shown':
          final List<int> sumas = List<int>.from(decoded['punt'] ?? []);
          _ref.read(gameProvider.notifier).showVidenteDice(sumas);
          break;

        // Tipo de mensaje de inicio de minijuego
        case 'ini_minijuego':
          _localPlayerSentEndRound = false;

          final String? name = decoded['minijuego'];
          final String? desc = decoded['descripcion'];
          // 'details' no se extrae de aquí para evitar sobreescribir datos recibidos durante la animación

          debugPrint(
              "Minijuego ${name?.toUpperCase() ?? "DESCONOCIDO"} encolado. Detalles: ${desc?.toUpperCase() ?? "DESCONOCIDO"}");

          if (name != null) {
            // Esperar a que la cola de animación se vacíe antes de lanzarlo
            Future.doWhile(() async {
              if (_ref.read(gameProvider.notifier).isAnimationQueueEmpty) {
                return false; // Rompe el bucle, ya no hay animación
              }
              await Future.delayed(const Duration(milliseconds: 200));
              return true; // Sigue esperando
            }).then((_) {
              // Ahora sí, el muñeco ha llegado a la casilla. Lanzamos el minijuego.
              _ref.read(gameProvider.notifier).startMinigame(
                    name: name,
                    description: desc,
                    details: _ref.read(gameProvider).minigameDetails,
                  );
            });
          }
          break;

        // Tipo de mensaje de resultados de minijuego
        case 'minijuego_resultados':
          // El backend envía "nuevo_orden" como un Map {jugador: posicion},
          // NO como una lista "order". Ordenamos por valor ascendente para
          // reconstruir el turno correcto: posicion 1 primero, 4 último.
          final Map<String, dynamic> rawOrder =
              Map<String, dynamic>.from(decoded['nuevo_orden'] ?? {});
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
          final balances = decoded['balances'] as Map<String, dynamic>;

          // 1. Mostrar resultado de Doble o Nada a todos y desbloquear a los espectadores
          final gameState = _ref.read(gameProvider);
          final blockingUser = gameState.blockingTurnPlayer;

          // LA CLAVE ESTÁ AQUÍ: Comprobamos estrictamente que estamos en el Doble o Nada
          // y que las monedas que han cambiado incluyen al jugador que está apostando.
          if (blockingUser != null &&
              gameState.minigameDetails?['minijuego'] == 'Doble o Nada' &&
              balances.containsKey(blockingUser)) {
            final oldPlayer = gameState.players.firstWhere(
                (p) => p.id == blockingUser || p.username == blockingUser,
                orElse: () => gameState.players.first);
            final diff = (balances[blockingUser] as int) - oldPlayer.coins;

            // Mostramos a todos lo que ha pasado con la apuesta
            if (diff != 0) {
              final msg = diff > 0
                  ? "¡$blockingUser ha GANADO $diff monedas en Doble o Nada! 🪙"
                  : "¡$blockingUser ha PERDIDO ${diff.abs()} monedas en Doble o Nada! 💸";
              _eventController.add({'type': 'info_message', 'message': msg});
            }

            // Los espectadores esperan 3.2s para sincronizarse
            final myUsername = _ref.read(authProvider).username ?? '';
            if (myUsername != blockingUser) {
              Future.delayed(const Duration(milliseconds: 3200), () {
                if (_isConnected) {
                  _ref.read(gameProvider.notifier).clearBlockingTurnPlayer();
                  checkAndFinalizeTurn();
                }
              });
            }
          }

          // 2. Para cada jugador en el Map, actualizamos su balance
          balances.forEach((userId, coins) {
            _ref
                .read(gameProvider.notifier)
                .updateInventoryAndBalance(userId, newBalance: coins as int);
          });

          // 3. Revisamos si es el final de la ronda de todos los jugadores
          if (_localPlayerSentEndRound &&
              _ref.read(gameProvider).activePlayerIndex == 0) {
            _localPlayerSentEndRound = false;
            _ref.read(gameProvider.notifier).setWaitingForMinigameChoice(true);
          }
          break;

        // Tipo de mensaje para elegir minijuego
        case 'choose_minijuego':
          debugPrint("El backend pide elegir minijuego.");

          // Extraemos la lista enviada por el backend
          final minijuegosList = decoded['minijuegos'] as List<dynamic>? ?? [];
          // Mapeamos para obtener solo el nombre del minijuego
          final choices =
              minijuegosList.map((m) => m['nombre'] as String).toList();

          _ref.read(gameProvider.notifier).setMinigameChoices(choices);
          break;

        case 'obtener_objeto':
          debugPrint(' MENSAJE RULETA RECIBIDO: $decoded');
          final itemName = decoded['objeto'];
          final desc = decoded['descripcion'];
          final userRuleta = decoded['user'];

          // Marcar al jugador de la ruleta como bloqueante (refuerza tipo_casilla)
          _ref.read(gameProvider.notifier).setBlockingTurnPlayer(userRuleta);

          // ENCOLAMOS la ruleta para que se ejecute secuencialmente DESPUÉS del movimiento que la provocó
          _ref.read(gameProvider.notifier).enqueueTask(() async {
            // Añadimos un pequeño delay extra para que el jugador aprecie que ha llegado a la casilla
            await Future.delayed(const Duration(milliseconds: 400));
            _ref.read(gameProvider.notifier).showObtainedItem(itemName, desc, userRuleta);
            
            // Pausamos la cola de animaciones hasta que el modal de ruleta se cierre completamente
            await _ref.read(gameProvider.notifier).waitForRouletteToClose();
          });
          break;

        case 'penalizacion_actualizada':
          final userId = decoded['user'];
          final turns = decoded['penalizacion'] ?? 0;
          _ref.read(gameProvider.notifier).updatePenalty(userId, turns);
          break;

        case 'penalizacion_eliminada':
          final userId = decoded['user'];
          _ref.read(gameProvider.notifier).updatePenalty(userId, 0);
          break;

        case 'poker_inicio_ronda':
        case 'poker_nueva_fase':
        case 'poker_resultados':
        case 'poker_victoria_abandono':
        case 'poker_flop':
        case 'poker_turno':
        case 'poker_bote':
        case 'poker_cartas':
          debugPrint(" [WS] Poker message: ${decoded['type']}");
          // Actualizar los detalles del minijuego en el estado global para que PokerGame reaccione
          _ref.read(gameProvider.notifier).updateMinigameDetails(decoded);
          break;

        case 'minijuego_casilla':
          // Guardamos los detalles iniciales en el provider
          _ref.read(gameProvider.notifier).updateMinigameDetails(decoded);
          break;

        case 'info':
          final String msg = decoded['message'] ?? '';
          if (msg.isNotEmpty) {
            _eventController.add({'type': 'info_message', 'message': msg});
          }
          break;

        // Tipo de mensaje por defecto
        default:
          // Si el mensaje tiene una clave "error""
          if (decoded.containsKey('error')) {
            // Iprimimos el error y liberamos la acción
            debugPrint('Error desde el backend: ${decoded['error']}');
            _isActionLocked = false;
            // Notificamos al minijuego activo para que pueda recuperarse
            _ref.read(gameProvider.notifier).updateMinigameDetails({
              'type': 'backend_error',
              'error': decoded['error'],
            });
          } else {
            debugPrint(
                'Mensaje WebSocket parseado, pero no manejado: $decoded');
          }
      }

      // Capturamos también errores directos si vienen fuera de type
      if (decoded.containsKey('error') && decoded['type'] == null) {
        // Mismo procedimiento que antes
        debugPrint('Error desde el backend: ${decoded['error']}');
        _isActionLocked = false;
      }
      // Capturamos cualquier otro error que pueda ocurrir al decodificar o manejar el mensaje
    } catch (e) {
      debugPrint('Error decodificando el mensaje de WebSocket: $e');
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
      debugPrint("No se pudo enviar 'move_player' porque no hay conexión.");
    }
  }

  // Función privada para mandar la acción de fin de ronda al backend
  void sendEndRound() {
    // Comprobamos previamente que el canal existe y está conectado antes de mandar la acción
    if (_channel != null && _isConnected) {
      // Creamos el payload como se especifica en la domuentacion de los WS
      final payload = {'action': 'end_round', 'payload': {}};
      // DEBUG: guarda que imprimmos para comprobar que se manda correctamente
      debugPrint(' Enviando END_ROUND al backend');
      // Mandamos el paquete codificado al backend.
      _channel!.sink.add(jsonEncode(payload));

      _isActionLocked = false; // LIBERA EL DADO PARA EL PRÓXIMO TURNO
      // Marcamos que este jugador terminó su turno. La pantalla de espera
      // se activará en 'balances_changed', que llega cuando TODOS han terminado.
      _localPlayerSentEndRound = true;
      // Si no hay conexion imrpimimos un msj de error
    } else {
      debugPrint("No se pudo enviar 'end_round' porque no hay conexión.");
    }
  }

  // Funcion publica para enviar la puntuación de un minijuego al backend.
  // Se hace para aquellos minijuegos que requieren enviar la puntuación (como Reflejos o Tren).
  void sendMinigameScore(dynamic score, {double? objetivo}) {
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
      debugPrint("No se pudo enviar 'score_minijuego' porque no hay conexión.");
    }
  }

  // Funcion pública para enviar la elección de minijuego al backend.
  // Se llama cuando el videojugador elige un minijuego.
  void sendMinigameChoice(String minigameName) {
    if (_channel != null && _isConnected) {
      // creamos el payload como se especifica en la docuemntacion de los WS
      final payload = {
        'action': 'ini_round',
        'payload': {'minijuego': minigameName, 'descripcion': ''}
      };
      // Enviamos el paquete codificado al backend.
      _channel!.sink.add(jsonEncode(payload));
      // Si no hay conexion imrpimimos un msj de error
    } else {
      debugPrint("No se pudo enviar 'ini_round' porque no hay conexión.");
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
      debugPrint("No se pudo enviar la acción porque no hay conexión.");
    }
  }

  /// Envía una acción de póker al backend (apostar, igualar, retirarse, etc.)
  void sendPokerAction(String decision, int cantidad) {
    if (_channel != null && _isConnected) {
      final payload = {
        'action': 'poker_accion',
        'payload': {
          'decision': decision,
          'cantidad': cantidad,
        }
      };
      _channel!.sink.add(jsonEncode(payload));
      debugPrint(" [POKER] Acción enviada: $decision ($cantidad)");
    } else {
      debugPrint("No se pudo enviar 'poker_accion' porque no hay conexión.");
    }
  }

  /// Función robusta para evaluar si un turno ha finalizado por completo
  void checkAndFinalizeTurn() {
    // Usamos un bucle para esperar a que las animaciones terminen, en lugar de un delay fijo
    Future.doWhile(() async {
      final gameState = _ref.read(gameProvider);
      final isQueueEmpty =
          _ref.read(gameProvider.notifier).isAnimationQueueEmpty;

      // Si la cola no está vacía o la ruleta está abierta, seguimos esperando
      if (!isQueueEmpty || gameState.obtainedItemName != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        return true; // Continuar esperando
      }
      return false; // Salir del bucle, todo está listo
    }).then((_) {
      final gameState = _ref.read(gameProvider);

      // Verificamos que no haya bloqueos de eventos
      if (gameState.currentPhase == GamePhase.boardTurn &&
          gameState.blockingTurnPlayer == null) {
        if (_pendingTurnAdvance) {
          final activeId = gameState.turnOrder.isNotEmpty
              ? gameState.turnOrder[gameState.activePlayerIndex]
              : null;

          _pendingTurnAdvance = false; // Consumimos el ticket

          // 1. Avanzamos el turno en la interfaz local
          _ref.read(gameProvider.notifier).advanceTurn();

          // 2. Si es nuestro turno local, le damos el aviso de fin al servidor
          final myUsername = _ref.read(authProvider).username;
          if (activeId == myUsername) {
            sendEndRound();
          }
        }
      }
    });
  }
}
