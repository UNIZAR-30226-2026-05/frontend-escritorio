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

  // Indica que el jugador ha caído en una casilla con minijuego y el minijuego
  // todavía no ha arrancado. Bloquea checkAndFinalizeTurn hasta que
  // startMinigame cambie la fase a minigameTile.
  bool _pendingTileMinigame = false;

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
          final myUsername = _ref.read(authProvider).username;
          if (diceTotal > 0 && userId == myUsername) {
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
          break;

        // Tipo de mensaje de actualizar el lobby
        case 'lobby_update':
          debugPrint("Lobby update: \${decoded['message']}");
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
          // NOTA: Ya no hace falta bloquear el turno preventivamente aquí
          // porque el servidor no mandará el turno_de del siguiente hasta que
          // el jugador actual envíe su 'fin_turno'.
          break;

        case 'turno_de':
          final String nextUser = decoded['nombre_jugador'] ?? '';
          final int ronda = decoded['ronda'] ?? 1;
          debugPrint("¡Es el turno de: $nextUser (Ronda $ronda)!");
          _ref
              .read(gameProvider.notifier)
              .setActivePlayerName(nextUser, round: ronda);

          // Al recibir un nuevo turno, reseteamos todos los flags del turno anterior.
          _localPlayerSentEndRound = false;
          _isActionLocked = false;
          _pendingTileMinigame = false;
          _pendingTurnAdvance = false;
          _ref.read(gameProvider.notifier).clearTurnPurchasedItems();
          break;

        case 'dados_mejorados':
          debugPrint("¡Dados mejorados con éxito!");
          _ref.read(gameProvider.notifier).setImprovedDice(true);
          break;

        case 'fin_partida':
          final String winner = decoded['winner'] ?? 'Desconocido';
          debugPrint(
              '¡FIN DE PARTIDA! El jugador $winner ha llegado a la meta.');
          // El cambio a GamePhase.finished lo maneja el game_provider
          // automáticamente cuando la animación del jugador alcanza la casilla final.
          break;

        case 'objeto_comprado':
          final objeto = decoded['objeto'] as String? ?? 'Objeto desconocido';
          _ref.read(gameProvider.notifier).addTurnPurchasedItem(objeto);
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
          final String? name = decoded['minijuego'];
          final isTileMinigame = name == 'Mano de Poker' ||
              name == 'Poker' ||
              name == 'Dilema del Prisionero' ||
              name == 'Doble o Nada';

          // Activamos el flag aquí (no en minijuego_casilla) porque ini_minijuego
          // solo llega a los participantes reales del minijuego de casilla,
          // garantizando que también llegará la señal que lo limpia.
          if (isTileMinigame) _pendingTileMinigame = true;

          if (!isTileMinigame) {
            _localPlayerSentEndRound = false;
          }

          final String? desc = decoded['descripcion'];

          // Para minijuegos de ronda (ej. Mayor o Menor), los detalles solo llegan
          // en este mensaje. Para minijuegos de casilla, minijuego_casilla ya los
          // guardó; usamos esos como fallback para no pisar datos del póker.
          final Map<String, dynamic>? msgDetails = decoded['detalles'] != null
              ? Map<String, dynamic>.from(decoded['detalles'] as Map)
              : null;

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
              // Limpiamos el flag ANTES de llamar a startMinigame.
              // A partir de aquí la fase pasa a minigameTile, que es lo que
              // usa checkAndFinalizeTurn para saber que no debe enviar fin_turno.
              if (isTileMinigame) _pendingTileMinigame = false;
              // Ahora sí, el muñeco ha llegado a la casilla. Lanzamos el minijuego.
              _ref.read(gameProvider.notifier).startMinigame(
                    name: name,
                    description: desc,
                    details:
                        msgDetails ?? _ref.read(gameProvider).minigameDetails,
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
          final activeUser = gameState.activePlayerName;

          // LA CLAVE ESTÁ AQUÍ: Comprobamos estrictamente que estamos en el Doble o Nada
          // y que las monedas que han cambiado incluyen al jugador que está apostando.
          if (activeUser != null &&
              gameState.minigameName == 'Doble o Nada' &&
              balances.containsKey(activeUser)) {
            final oldPlayer = gameState.players.firstWhere(
                (p) => p.id == activeUser || p.username == activeUser,
                orElse: () => gameState.players.first);
            final diff = (balances[activeUser] as int) - oldPlayer.coins;

            // Computed locally instead of needing a backend change
            final map = {
              activeUser: {
                'apuesta': diff.abs(),
                'ganado':
                    diff > 0 || diff == 0, // Si es 0 es neutro, ponemos ganado
              }
            };
            _ref
                .read(gameProvider.notifier)
                .setMinigameResults(map, [activeUser]);
          }

          // 2. Para cada jugador en el Map, actualizamos su balance
          balances.forEach((userId, coins) {
            _ref
                .read(gameProvider.notifier)
                .updateInventoryAndBalance(userId, newBalance: coins as int);
          });

          break;

        case 'robar_banquero':
          final victima = decoded['nombre'] as String;
          final monedas = decoded['monedas'] as int;
          // El banquero es el jugador activo actualmente en su turno
          final banquero =
              _ref.read(gameProvider).activePlayerName ?? 'Banquero';
          final message =
              '${banquero.toUpperCase()} HA ROBADO $monedas MONEDA${monedas > 1 ? 'S' : ''} A ${victima.toUpperCase()}';
          _ref.read(gameProvider.notifier).setTurnTheftMessage(message);
          Future.delayed(const Duration(seconds: 4), () {
            _ref.read(gameProvider.notifier).clearTurnTheftMessage();
          });
          break;

        case 'round_ended':
          debugPrint(
              "Fin de ronda detectado. Esperando elección de minijuego...");
          _ref.read(gameProvider.notifier).setWaitingForMinigameChoice(true);
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

          // ENCOLAMOS la ruleta para que se ejecute secuencialmente DESPUÉS del movimiento que la provocó
          _ref.read(gameProvider.notifier).enqueueTask(() async {
            // Añadimos un pequeño delay extra para que el jugador aprecie que ha llegado a la casilla
            await Future.delayed(const Duration(milliseconds: 400));
            _ref
                .read(gameProvider.notifier)
                .showObtainedItem(itemName, desc, userRuleta);

            // Pausamos la cola de animaciones hasta que el modal de ruleta se cierre completamente
            await _ref.read(gameProvider.notifier).waitForRouletteToClose();
          });
          break;

        case 'penalizacion_actualizada':
          final affectedUser = decoded['user'] as String;
          final turns = decoded['penalizacion'] ?? 0;
          _ref.read(gameProvider.notifier).updatePenalty(affectedUser, turns);
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
        case 'turno_poker':
        case 'poker_apuesta_actualizada':
        case 'poker_apuesta':
          debugPrint(" [WS] Poker message: ${decoded['type']}");
          // Actualizar los detalles del minijuego en el estado global para que PokerGame reaccione
          _ref.read(gameProvider.notifier).updateMinigameDetails(decoded);
          break;

        // El backend envía {"type": "error", "message": "..."} cuando rechaza
        // una acción de poker (apuesta insuficiente, no puede pasar, etc.).
        // Lo reenviamos como backend_error al minijuego activo para que
        // reactive el turno del jugador y evite un deadlock.
        case 'error':
          final errorMsg =
              decoded['message']?.toString() ?? 'Error desconocido';
          debugPrint(' [WS] Error del backend: $errorMsg');
          _isActionLocked = false;
          _ref.read(gameProvider.notifier).updateMinigameDetails({
            'type': 'backend_error',
            'error': errorMsg,
          });
          break;

        case 'dilema_resultados':
          // El backend de Dilema del Prisionero nunca envía minijuego_resultados,
          // así que construimos el equivalente aquí para que _resultsSubscription
          // del overlay se dispare y cierre el minijuego correctamente.
          final decisiones =
              Map<String, dynamic>.from(decoded['decisiones'] as Map? ?? {});
          final recompensas =
              Map<String, dynamic>.from(decoded['recompensas'] as Map? ?? {});
          final sortedEntries = recompensas.entries.toList()
            ..sort((a, b) => (b.value as num).compareTo(a.value as num));
          int pos = 1;
          final dilemaResults = <String, dynamic>{};
          for (final entry in sortedEntries) {
            dilemaResults[entry.key] = {
              'posicion': pos++,
              'score': decisiones[entry.key] ?? '',
            };
          }
          final dilemaTurnOrder = sortedEntries.map((e) => e.key).toList();
          _ref
              .read(gameProvider.notifier)
              .setMinigameResults(dilemaResults, dilemaTurnOrder);
          break;

        case 'minijuego_casilla':
          // Solo guardamos los detalles del minijuego. El flag _pendingTileMinigame
          // se activa en ini_minijuego (cuando sabemos que somos participantes),
          // no aquí (que es broadcast a todos), para evitar que se bloquee
          // checkAndFinalizeTurn en jugadores que nunca recibirán ini_minijuego.
          _ref.read(gameProvider.notifier).updateMinigameDetails(decoded);

          final name = decoded['minijuego'] as String?;
          final user = decoded['user'] as String?;
          final myUsername = _ref.read(authProvider).username;

          // Para Doble o Nada y Dilema del Prisionero, los espectadores no reciben
          // ini_minijuego, así que forzamos el inicio localmente para renderizar el overlay de espera.
          if ((name == 'Doble o Nada' || name == 'Dilema del Prisionero') &&
              user != myUsername) {
            // Dilema del Prisionero solo arranca cuando DOS jugadores coinciden en la misma
            // casilla. Como minijuego_casilla se emite cada vez que alguien cae (aunque
            // esté solo), verificamos que haya al menos 2 jugadores en esa casilla antes de
            // mostrar el overlay de espera a los espectadores.
            if (name == 'Dilema del Prisionero') {
              final gameState = _ref.read(gameProvider);
              final trigger = gameState.players.firstWhere(
                (p) => p.username == user || p.id == user,
                orElse: () => gameState.players.first,
              );
              final onSameTile = gameState.players
                  .where((p) => p.currentTileIndex == trigger.currentTileIndex)
                  .length;
              if (onSameTile < 2) break;
            }

            Future.doWhile(() async {
              if (_ref.read(gameProvider.notifier).isAnimationQueueEmpty) {
                return false;
              }
              await Future.delayed(const Duration(milliseconds: 200));
              return true;
            }).then((_) {
              _ref.read(gameProvider.notifier).startMinigame(
                    name: name!,
                    description: decoded['descripcion'],
                    details: decoded,
                  );
            });
          }

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
    if (_localPlayerSentEndRound) return;

    // Comprobamos previamente que el canal existe y está conectado antes de mandar la acción
    if (_channel != null && _isConnected) {
      // Creamos el payload como se especifica en la domuentacion de los WS
      final payload = {'action': 'fin_turno', 'payload': {}};
      // DEBUG: guarda que imprimmos para comprobar que se manda correctamente
      debugPrint(' Enviando FIN_TURNO al backend');
      // Mandamos el paquete codificado al backend.
      _channel!.sink.add(jsonEncode(payload));

      _isActionLocked = false; // LIBERA EL DADO PARA EL PRÓXIMO TURNO
      _localPlayerSentEndRound = true;
    } else {
      debugPrint("No se pudo enviar 'fin_turno' porque no hay conexión.");
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
        'action': 'select_mini',
        'payload': {'minijuego': minigameName, 'descripcion': ''}
      };
      // Enviamos el paquete codificado al backend.
      _channel!.sink.add(jsonEncode(payload));
      // Si no hay conexion imrpimimos un msj de error
    } else {
      debugPrint("No se pudo enviar 'select_mini' porque no hay conexión.");
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

  /// Función robusta para evaluar si un turno ha finalizado por completo.
  /// Espera a que todas las animaciones, la ruleta y cualquier minijuego de
  /// casilla hayan terminado antes de enviar fin_turno al backend.
  void checkAndFinalizeTurn() {
    Future.doWhile(() async {
      final gameState = _ref.read(gameProvider);
      final isQueueEmpty =
          _ref.read(gameProvider.notifier).isAnimationQueueEmpty;

      // Salida temprana si no es el turno del jugador local: no hace falta
      // esperar ni enviar nada, y así evitamos un bucle infinito en los
      // jugadores que no participan en el minijuego de casilla.
      final myUsername = _ref.read(authProvider).username;
      if (gameState.activePlayerName != myUsername) return false;

      // Seguimos esperando mientras:
      //   - La cola de animaciones no esté vacía.
      //   - La ruleta de objeto esté abierta.
      //   - Haya un minijuego de casilla inminente (_pendingTileMinigame).
      //   - Un minijuego de casilla esté en curso (fase minigameTile).
      if (!isQueueEmpty ||
          gameState.obtainedItemName != null ||
          _pendingTileMinigame ||
          gameState.currentPhase == GamePhase.minigameTile) {
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      }
      return false;
    }).then((_) {
      final gameState = _ref.read(gameProvider);

      if (gameState.currentPhase == GamePhase.boardTurn) {
        if (_pendingTurnAdvance) {
          _pendingTurnAdvance = false; // Consumimos el ticket

          // Solo el jugador activo envía fin_turno.
          // El ticket _pendingTurnAdvance actúa como mutex: si dos llamadas
          // concurrentes llegan aquí, solo la primera envía.
          final myUsername = _ref.read(authProvider).username;
          if (gameState.activePlayerName == myUsername) {
            sendEndRound();
          }
        }
      }
    });
  }
}
