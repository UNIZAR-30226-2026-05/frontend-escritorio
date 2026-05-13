import 'dart:async';
import 'dart:math' show pi, cos, sin;

// Importa las dependencias necesarias para Flutter, Riverpod y navegación.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importa los servicios y providers específicos del lobby, así como el provider de autenticación
import '../data/lobby_websocket_service.dart';
import '../data/session_websocket_service.dart';
import '../domain/lobby_models.dart';
import 'controllers/lobby_provider.dart';
import '../../auth/presentation/controllers/auth_provider.dart';
import '../../../core/widgets/retro_widgets.dart';
import '../../board/presentation/widgets/character_selection_modal.dart';
import 'widgets/friend_search_modal.dart';
import 'widgets/rules_modal.dart';

// AVISO: los metodos build se invocan automaticamente cada vex que cambia el estado del lobby.

// Pantalla principal del lobby. Gestiona tres estados visuales:
//   1. Lobby normal (el jugador no está en ninguna partida).
//   2. Lobby en sala  (el jugador ha creado o se ha unido a una partida).
//   3. Selección de personaje (la partida ha comenzado y toca elegir personaje).
// El cambio entre estados lo dirige LobbyState usando Riverpod.
class LobbyScreen extends ConsumerStatefulWidget {
  // Constructor de la clase.
  const LobbyScreen({super.key});

  // createState devuelve una instancia de _LobbyScreenState, que es donde se implementa toda
  // la lógica y la UI del lobby.
  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

// Clase de estado asociada a LobbyScreen. Aquí se manejan los controladores de texto,
// los temporizadores, la lógica de conexión/desconexión al WebSocket, y la construcción
// de los widgets.
class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  // Controlador y foco del campo de texto donde el usuario escribe el código de partida.
  // Sirve para utilizar la tecla intro para unirse a la partida sin necesidad de un botón adicional.
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  // Estado para mostrar la pantalla de cambiar contraseña en vez del panel central.
  bool _showPasswordChange = false;

  // Al montar el widget conectamos el WebSocket de sesión para recibir
  // invitaciones y estado online de los amigos. El WS vive mientras el
  // usuario esté en el lobby; en logout o al destruir el widget se cierra.
  @override
  void initState() {
    super.initState();
    // addPostFrameCallback asegura que el ref se lee después del primer frame,
    // momento en el que el authProvider ya está disponible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (auth.isAuthenticated && auth.username != null && auth.token != null) {
        ref.read(sessionWebSocketProvider).connect(auth.username!, auth.token!);
        debugPrint(
            'Conectado al WebSocket de sesión como ${auth.username}'); // Debug: log de conexión
      }
    });
  }

  // Metodo de limpieza que se llama al destruir el widget.
  @override
  void dispose() {
    // Libera los recursos del controlador y el foco cuando el widget se destruye.
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  // Metodo privado para cerrar la conexión WebSocket de la sala actual y limpia el estado de partida
  // sin cerrar la sesión del usuario.
  void _abandonarPartida() {
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
  }

  // Metodo privado para llamar al backend, crear una nueva partida, recibir el gameId y
  // abrir el WebSocket de sala para empezar a recibir eventos en tiempo real.
  Future<void> _crearPartida() async {
    // Desconecta cualquier sala previa antes de crear una nueva.
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
    // Lee el token de autenticación del provider de auth para incluirlo en la petición al backend.
    final token = ref.read(authProvider).token!;
    // Llama al método crearPartida del provider de lobby, que hace la petición al backend y actualiza el estado.
    final success = await ref.read(lobbyProvider.notifier).crearPartida(token);
    // Si el backend responde con exito y el widget sigue montado...
    if (success && mounted) {
      // Guardamos el gameId.
      final gameId = ref.read(lobbyProvider).gameId!;
      // Abrimos la conexión WebSocket para la sala recién creada.
      ref.read(lobbyWebSocketProvider).connect(gameId, token);
    }
  }

  // Metodo privado para validar que el campo de código no esté vacío, llamar al backend para unirse
  // a la partida indicada y abrir el WebSocket de sala si el servidor lo acepta.
  Future<void> _unirseConCodigo() async {
    // Lee el código de partida del campo de texto, eliminando espacios al principio y al final.
    final code = _codeController.text.trim();
    // Si el campo está vacio, no hacer nada.
    if (code.isEmpty) return;
    // Se lee el token de autenticación del provider de auth para incluirlo en la petición al backend.
    final token = ref.read(authProvider).token!;
    // Se desconecta cualquier sala previa antes de intentar unirse a otra.
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
    // Se trata de unirse a la partida con el código seleccionado.
    final accepted =
        await ref.read(lobbyProvider.notifier).unirsePartida(code, token);
    if (accepted) {
      // Si el back acepta la peticion nos conectamos al ws de la partida.
      ref.read(lobbyWebSocketProvider).connect(code, token);
    }
  }

  // Une al usuario a la partida de una invitación recibida y la elimina de la lista.
  Future<void> _joinInvite(String gameId) async {
    final token = ref.read(authProvider).token!;
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
    final accepted =
        await ref.read(lobbyProvider.notifier).unirsePartida(gameId, token);
    if (accepted && mounted) {
      ref.read(lobbyWebSocketProvider).connect(gameId, token);
    }
    ref.read(lobbyProvider.notifier).removeInvite(gameId);
  }

  // Metodo privado para cerrar el WebSocket, resetear el estado del lobby y llamar al logout de auth,
  // lo que redirigirá automáticamente a la pantalla de login por el router.
  Future<void> _logout() async {
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(sessionWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).reset();
    await ref.read(authProvider.notifier).logout();
  }

  // Metodo build que construye la UI del lobby.
  // Se basa en el estado actual del lobby para decidir qué mostrar.
  @override
  Widget build(BuildContext context) {
    // ref.listen reacciona a cambios de estado.
    ref.listen<LobbyState>(lobbyProvider, (prev, next) {
      // Cuando todos los jugadores han seleccionado personaje, desconecta el WS
      // del lobby. La navegación a /game la gestiona el router automáticamente
      // al detectar que allCharactersSelected == true en lobbyProvider.
      if (prev != null &&
          !prev.allCharactersSelected &&
          next.allCharactersSelected) {
        ref.read(lobbyWebSocketProvider).disconnect();
      }
      // Si el servidor fuerza la desconexión (sesión duplicada), muestra aviso.
      if (prev != null && !prev.forceDisconnected && next.forceDisconnected) {
        // ScaffoldMessenger es un widget de Flutter que permite mostrar
        // SnackBars (mensajes temporales que aparecen en la parte inferior de la pantalla).
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.serverMessage.isNotEmpty
                ? next.serverMessage
                : 'Sesión iniciada en otro dispositivo'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        // Limpia el flag de forceDisconnected para que el mensaje solo se muestre una vez.
        ref.read(lobbyProvider.notifier).clearForceDisconnected();
      }
      // Las invitaciones ya se muestran en el panel izquierdo; solo limpiamos
      // lastInvite para que el flag no quede activo indefinidamente.
      if (next.lastInvite != null &&
          (prev == null || prev.lastInvite != next.lastInvite)) {
        ref.read(lobbyProvider.notifier).clearLastInvite();
      }
      // Error devuelto por el WS de sesión al enviar una solicitud de amistad
      // (p. ej. el destinatario no existe). Lo mostramos y lo limpiamos.
      if (next.friendRequestError != null &&
          (prev == null ||
              prev.friendRequestError != next.friendRequestError)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.friendRequestError!),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
        ref.read(lobbyProvider.notifier).clearFriendRequestError();
      }
      // Si el error indica que el token ha caducado o es inválido, cierra sesión.
      if (prev != null && next.error != null && next.error != prev.error) {
        final error = next.error!.toLowerCase();
        if (error.contains('autenticad') ||
            error.contains('unauthorized') ||
            error.contains('401')) {
          _logout();
        }
      }
    });

    // watch hace que el widget se reconstruya cada vez que el estado del lobby cambia.
    final lobbyState = ref.watch(lobbyProvider);
    // Lee el nombre de usuario del provider de auth para mostrarlo en la interfaz.
    final username = ref.watch(authProvider).username ?? '';

    // Si la partida ha comenzado pero todavía no se han elegido todos los personajes,
    // muestra la pantalla de selección con el tablero de fondo.
    if (lobbyState.gameId != null &&
        lobbyState.gameStarted &&
        !lobbyState.allCharactersSelected) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Tablero de fondo
            Image.asset('assets/images/board/tablero_def.png',
                fit: BoxFit.cover),
            // Overlay oscuro
            Container(color: Colors.black.withValues(alpha: 0.6)),
            // Modal de selección de personaje centrado
            Center(
              child: CharacterSelectionModal(
                lobbyState: lobbyState,
                currentUsername: username,
              ),
            ),
          ],
        ),
      );
    }

    // Devuelve la construccion del lobby.
    return Scaffold(
      // Fondo negro mientras la imagen de lobby carga, evitando parpadeo blanco.
      backgroundColor: Colors.black,
      // Definimos el cuerpo como un stack para poder apilar widgets (construccion uno sobre otro).
      body: Stack(
        // StackFit.expand hace que los "hijos" del Stack cubran todo el espacio disponible.
        fit: StackFit.expand,
        children: [
          // Imagen de fondo que cubre toda la pantalla HAY QUE CAMBIARLA.
          Image.asset('assets/images/ui/lobby.png', fit: BoxFit.cover),

          // LayoutBuilder proporciona el ancho y alto reales del área disponible,
          // de modo que todos los tamaños se calculan de forma proporcional
          // en lugar de usar valores fijos en píxeles.
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Row(
              // Alineación de los hijos a lo largo del eje principal (horizontal).
              // 3 columnas verticales.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Columna izquierda: partidas de amigos y botón de logout.
                SizedBox(
                  width: w * 0.33,
                  child: _LeftPanel(
                    onLogout: _logout,
                    onJoinInvite: _joinInvite,
                    onDismissInvite: (gameId) =>
                        ref.read(lobbyProvider.notifier).removeInvite(gameId),
                    username: username,
                    w: w,
                    h: h,
                  ),
                ),
                // Columna central: crear partida / cambiar contraseña.
                SizedBox(
                  width: w * 0.34,
                  child: _showPasswordChange
                      ? _PasswordChangePanel(
                          w: w,
                          h: h,
                          onBack: () =>
                              setState(() => _showPasswordChange = false),
                        )
                      : _CenterPanel(
                          lobbyState: lobbyState,
                          username: username,
                          codeController: _codeController,
                          codeFocus: _codeFocus,
                          onCrear:
                              lobbyState.isLoading || lobbyState.gameId != null
                                  ? null
                                  : _crearPartida,
                          onUnirse: lobbyState.gameId != null
                              ? null
                              : _unirseConCodigo,
                          onAbandonar: _abandonarPartida,
                          w: w,
                          h: h,
                        ),
                ),
                // Columna derecha: lista de amigos y enlace a las reglas.
                SizedBox(
                  width: w * 0.33,
                  child: _RightPanel(w: w, h: h),
                ),
              ],
            );
          }),

          // Botón invisible sobre el pingüino "Reglas" (esquina inferior derecha)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => showDialog(
                context: context,
                barrierColor: Colors.black87,
                builder: (context) => const RulesModal(),
              ),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.12,
                height: MediaQuery.of(context).size.height * 0.22,
                color: Colors.transparent,
              ),
            ),
          ),

          // Botones inferiores izquierda: ajustes y logout
          Positioned(
            left: 10,
            bottom: 10,
            child: Row(
              children: [
                // Engranaje: cambiar contraseña
                GestureDetector(
                  onTap: () =>
                      setState(() => _showPasswordChange = !_showPasswordChange),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D1B4E),
                      border: Border.all(color: Colors.white54, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const _RetroGearIcon(size: 22, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                // Logout
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D1B4E),
                      border: Border.all(color: Colors.white54, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const _RetroLogoutIcon(size: 22, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// COLUMNA IZQUIERDA
// Muestra el nombre de usuario, el icono de logout y la lista de invitaciones
// a partida recibidas. Cada invitación puede aceptarse (unirse) o ignorarse.
class _LeftPanel extends ConsumerWidget {
  final VoidCallback onLogout;
  final Future<void> Function(String gameId) onJoinInvite;
  final void Function(String gameId) onDismissInvite;
  final String username;
  final double w, h;

  const _LeftPanel({
    required this.onLogout,
    required this.onJoinInvite,
    required this.onDismissInvite,
    required this.username,
    required this.w,
    required this.h,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleSize = h * 0.042;
    final textSize = h * 0.020;
    final invites = ref.watch(lobbyProvider.select((s) => s.invites));

    return Padding(
      padding: EdgeInsets.all(w * 0.018),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: nombre de usuario centrado-derecha, logout a la derecha.
          Row(
            children: [
              SizedBox(width: w * 0.09),
              Flexible(
                child: Text(
                  username,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: textSize * 2,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.white, blurRadius: 12),
                      Shadow(color: Colors.white54, blurRadius: 5),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: h * 0.12),

          Text(
            'Invitaciones',
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: titleSize,
              color: Colors.white,
              height: 1.3,
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 18),
                Shadow(color: Colors.white70, blurRadius: 8),
              ],
            ),
          ),

          SizedBox(height: h * 0.025),

          SizedBox(
            height: h * 0.55,
            child: invites.isEmpty
                ? Text(
                    'No tienes invitaciones\npendientes',
                    style: TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: textSize * 0.85,
                      color: Colors.white38,
                      height: 1.4,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: invites.length,
                    separatorBuilder: (_, __) => SizedBox(height: h * 0.015),
                    itemBuilder: (context, i) {
                      final invite = invites[i];
                      return _GameInviteRow(
                        invite: invite,
                        width: w * 0.30,
                        height: h * 0.055,
                        fontSize: textSize * 1.3,
                        onJoin: () => onJoinInvite(invite.gameId),
                        onDismiss: () {
                          ref.read(sessionWebSocketProvider).rejectInvite(invite.fromUser);
                          onDismissInvite(invite.gameId);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// COLUMNA CENTRAL
// Clase privada que define el panel central con toda la interacción principal del lobby.
// Recibe callbacks del padre para mantener la lógica fuera del widget de presentación.
class _CenterPanel extends StatelessWidget {
  // Estado actual del lobby: jugadores conectados, código de partida, errores, etc.
  final LobbyState lobbyState;
  // Nombre del usuario local, que siempre ocupa el slot 0.
  final String username;
  // Controlador y foco del campo donde se escribe el código de partida.
  final TextEditingController codeController;
  final FocusNode codeFocus;
  // Callbacks de acción. Son null cuando la acción no está disponible,
  // lo que desactiva visualmente el botón correspondiente.
  final VoidCallback? onCrear;
  final VoidCallback? onUnirse;
  final VoidCallback onAbandonar;
  // Dimensiones totales de la pantalla para calcular tamaños proporcionales.
  final double w, h;

  // Constructor de la clase, con todos los parámetros requeridos.
  const _CenterPanel({
    required this.lobbyState,
    required this.username,
    required this.codeController,
    required this.codeFocus,
    required this.onCrear,
    required this.onUnirse,
    required this.onAbandonar,
    required this.w,
    required this.h,
  });

  // Metodo privado que construye la lista de 4 slots de jugador.
  // El slot 0 siempre pertenece al usuario local (tanto dentro como fuera de partida).
  // Los slots 1-3 se rellenan con los jugadores conectados recibidos por WebSocket,
  // o quedan como null (se mostrarán como "Vacío") si no hay suficientes jugadores.
  List<String?> _buildSlots() {
    if (lobbyState.playersConnected.isEmpty) {
      return [username, null, null, null];
    }
    final slots = List<String?>.filled(4, null);
    for (int i = 0; i < lobbyState.playersConnected.length && i < 4; i++) {
      slots[i] = lobbyState.playersConnected[i];
    }
    return slots;
  }

  // Metodo build que construye la UI del panel central.
  @override
  Widget build(BuildContext context) {
    // Tamaños de texto y slots calculados proporcionalmente al alto y ancho de ventana.
    final titleSize = h * 0.042;
    final textSize = h * 0.026;
    final slotH = h * 0.058;
    final slotW = w * 0.080;
    final slots = _buildSlots();
    // Espacio entre slots y anchuras totales calculadas para alinear
    // la fila superior (código + slot0) con la inferior (slots 1, 2, 3).
    final slotGap = w * 0.010;
    final totalW = 3 * slotW + 2 * slotGap; // ancho total de ambas filas.
    final codeW =
        2 * slotW + slotGap; // ancho del bloque con e codigo y la slot0.

    // Column con mainAxisSize.max para que los Spacer distribuyan el espacio vertical.
    // Sin mainAxisSize.max los Spacer no tienen espacio en el que expandirse.
    return Padding(
      // Padding horizontal para que el contenido no toque los bordes del panel.
      padding: EdgeInsets.symmetric(horizontal: w * 0.015),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          // Espacio superior proporcional antes del botón de crear partida.
          // Spacer usa flex para distribuir el espacio restante entre los widgets de forma proporcional
          // IMPORTANTE: De forma proporcional.
          const Spacer(flex: 15),

          // Botón principal para crear una nueva sala. Se desactiva (onTap = null)
          // mientras hay una carga en curso o ya existe una partida activa.
          RetroImgButton(
            label: lobbyState.isLoading ? '...' : 'Crear partida',
            asset: 'assets/images/ui/btn_morado.png',
            width: w * 0.21,
            height: h * 0.16,
            fontSize: titleSize * 0.85,
            onTap: onCrear,
          ),

          // Separación proporcional entre el botón y el bloque de slots.
          const Spacer(flex: 10),

          // Fila superior del bloque de slots
          // Contiene el código de partida y el slot del usuario local.
          // Se envuelve en SizedBox(width: totalW) para que su ancho coincida
          // exactamente con el de la fila inferior y los slots queden alineados.
          SizedBox(
            width: totalW,
            child: Row(
              children: [
                // Bloque con el codigo de partida.
                SizedBox(
                  width: codeW,
                  child: lobbyState.gameId != null
                      // Si hay partida activa, muestra la etiqueta y el código con brillo.
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Código de partida:',
                              style: TextStyle(
                                fontFamily: 'Retro Gaming',
                                fontSize: textSize * 0.75,
                                color: Colors.white60,
                              ),
                            ),
                            SizedBox(height: h * 0.004),
                            // Codigo de la partida.
                            Text(
                              lobbyState.gameId!,
                              style: TextStyle(
                                fontFamily: 'Retro Gaming',
                                fontSize: titleSize * 1.1,
                                color: Colors.white,
                                shadows: const [
                                  Shadow(color: Colors.white, blurRadius: 14),
                                  Shadow(color: Colors.white54, blurRadius: 6),
                                ],
                              ),
                            ),
                          ],
                        )
                      // Si no hay partida activa, muestra un texto guía.
                      : Text(
                          'Crea una partida\npara obtener un código',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Retro Gaming',
                            fontSize: textSize * 0.75,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                ),
                SizedBox(width: slotGap),
                // Slot 0: siempre muestra al usuario local.
                _PlayerSlot(
                  name: slots[0] ?? 'Vacío',
                  filled: slots[0] != null,
                  width: slotW,
                  height: slotH,
                  fontSize: textSize * 0.72,
                ),
              ],
            ),
          ),

          // Separación proporcional entre la fila superior e inferior de slots.
          const Spacer(flex: 7),

          // Fila inferior del bloque de slots
          // Muestra los tres jugadores adicionales (slots 1, 2, 3).
          SizedBox(
            width: totalW,
            child: Row(
              children: [
                _PlayerSlot(
                    name: slots[1] ?? 'Vacío',
                    filled: slots[1] != null,
                    width: slotW,
                    height: slotH,
                    fontSize: textSize * 0.72),
                SizedBox(width: slotGap),
                _PlayerSlot(
                    name: slots[2] ?? 'Vacío',
                    filled: slots[2] != null,
                    width: slotW,
                    height: slotH,
                    fontSize: textSize * 0.72),
                SizedBox(width: slotGap),
                _PlayerSlot(
                    name: slots[3] ?? 'Vacío',
                    filled: slots[3] != null,
                    width: slotW,
                    height: slotH,
                    fontSize: textSize * 0.72),
              ],
            ),
          ),

          // Botón de abandonar y mensaje de error: solo se muestran si hay partida activa.
          // Se colocan inmediatamente debajo de los slots para que queden visualmente pegados.
          if (lobbyState.gameId != null) ...[
            SizedBox(height: h * 0.012),
            RetroImgButton(
              label: 'Abandonar',
              asset: 'assets/images/ui/btn_rojo.png',
              width: w * 0.13,
              height: h * 0.065,
              fontSize: textSize * 0.85,
              onTap: onAbandonar,
            ),
          ],
          if (lobbyState.error != null) ...[
            SizedBox(height: h * 0.008),
            Text(
              lobbyState.error!,
              style: TextStyle(
                color: Colors.redAccent,
                fontFamily: 'Retro Gaming',
                fontSize: textSize * 0.75,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          // Separación proporcional entre los slots y la sección de unirse por código.
          const Spacer(flex: 10),

          // Sección unirse con código
          // Título con doble sombra blanca para mantener el estilo de la ui.
          Text(
            'Unirse a una\npartida con código',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: titleSize,
              color: Colors.white,
              height: 1.3,
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 18),
                Shadow(color: Colors.white70, blurRadius: 8),
              ],
            ),
          ),
          SizedBox(height: h * 0.018),
          // Campo de texto donde el usuario escribe el código de la partida..
          // Al pulsar Enter se dispara onUnirse directamente, sin botón adicional.
          RetroField(
            label: '',
            controller: codeController,
            focusNode: codeFocus,
            fieldWidth: w * 0.23,
            fieldHeight: h * 0.085,
            labelFontSize: 0,
            inputFontSize: textSize,
            color: Colors.white,
            textInputAction: TextInputAction.done,
            onSubmitted: onUnirse,
          ),

          // Separación entre el campo de código y el texto informativo inferior.
          const Spacer(flex: 15),

          // Texto informativo que explica brevemente las opciones disponibles.
          Text(
            'Crea una partida e invita a\n tus amigos o únete a una\npartida',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: textSize,
              color: Colors.white,
              height: 1.5,
            ),
          ),

          // Pequeño margen inferior para que el texto no quede pegado al borde.
          const Spacer(flex: 5),
        ],
      ),
    );
  }
}

// PANEL CENTRAL: CAMBIAR CONTRASEÑA
// Reemplaza el panel central cuando el usuario pulsa el engranaje.
class _PasswordChangePanel extends ConsumerStatefulWidget {
  final double w, h;
  final VoidCallback onBack;

  const _PasswordChangePanel({
    required this.w,
    required this.h,
    required this.onBack,
  });

  @override
  ConsumerState<_PasswordChangePanel> createState() =>
      _PasswordChangePanelState();
}

class _PasswordChangePanelState extends ConsumerState<_PasswordChangePanel> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _currentPassFocus = FocusNode();
  final _newPassFocus = FocusNode();
  final _confirmPassFocus = FocusNode();

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _currentPassFocus.dispose();
    _newPassFocus.dispose();
    _confirmPassFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final current = _currentPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rellena todos los campos')),
      );
      return;
    }

    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    if (newPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La contraseña debe tener al menos 8 caracteres')),
      );
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .cambiarContrasena(current, newPass);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña cambiada con éxito')),
      );
      widget.onBack();
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Error al cambiar la contraseña')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleSize = widget.h * 0.042;
    final textSize = widget.h * 0.026;
    final fieldW = widget.w * 0.23;
    final fieldH = widget.h * 0.075;

    final isLoading = ref.watch(authProvider).isLoading;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.w * 0.015),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const Spacer(flex: 12),

          Text(
            'CAMBIAR\nCONTRASEÑA',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: titleSize,
              color: Colors.white,
              height: 1.3,
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 18),
                Shadow(color: Colors.white70, blurRadius: 8),
              ],
            ),
          ),

          const Spacer(flex: 6),

          RetroField(
            label: 'CONTRASEÑA ACTUAL',
            controller: _currentPassCtrl,
            focusNode: _currentPassFocus,
            fieldWidth: fieldW,
            fieldHeight: fieldH,
            labelFontSize: textSize * 0.7,
            inputFontSize: textSize * 0.9,
            obscureText: true,
            color: Colors.white,
            textInputAction: TextInputAction.next,
            onSubmitted: () =>
                FocusScope.of(context).requestFocus(_newPassFocus),
          ),

          const Spacer(flex: 4),

          RetroField(
            label: 'NUEVA CONTRASEÑA',
            controller: _newPassCtrl,
            focusNode: _newPassFocus,
            fieldWidth: fieldW,
            fieldHeight: fieldH,
            labelFontSize: textSize * 0.7,
            inputFontSize: textSize * 0.9,
            obscureText: true,
            color: Colors.white,
            textInputAction: TextInputAction.next,
            onSubmitted: () =>
                FocusScope.of(context).requestFocus(_confirmPassFocus),
          ),

          const Spacer(flex: 4),

          RetroField(
            label: 'CONFIRMAR NUEVA',
            controller: _confirmPassCtrl,
            focusNode: _confirmPassFocus,
            fieldWidth: fieldW,
            fieldHeight: fieldH,
            labelFontSize: textSize * 0.7,
            inputFontSize: textSize * 0.9,
            obscureText: true,
            color: Colors.white,
            textInputAction: TextInputAction.done,
            onSubmitted: isLoading ? null : _handleSave,
          ),

          const Spacer(flex: 6),

          RetroImgButton(
            label: isLoading ? '...' : 'GUARDAR',
            asset: 'assets/images/ui/btn_verde.png',
            width: widget.w * 0.15,
            height: widget.h * 0.08,
            fontSize: titleSize * 0.65,
            onTap: isLoading ? null : _handleSave,
          ),

          const Spacer(flex: 4),

          GestureDetector(
            onTap: isLoading ? null : widget.onBack,
            child: Text(
              'VOLVER AL MENÚ',
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: textSize * 0.75,
                color: Colors.white70,
                decoration: TextDecoration.underline,
              ),
            ),
          ),

          const Spacer(flex: 8),
        ],
      ),
    );
  }
}

// COLUMNA DERECHA
// Muestra la lista de TODOS los amigos (online y offline):
//   - Online: chip Contigo/Invitado/Invitar según el estado de la partida.
//   - Offline: chip "Offline" gris sin acción.
class _RightPanel extends ConsumerWidget {
  final double w, h;
  const _RightPanel({required this.w, required this.h});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleSize = h * 0.042;
    final textSize = h * 0.020;

    final allFriends = ref.watch(lobbyProvider.select((s) => s.allFriends));
    final online = ref.watch(lobbyProvider.select((s) => s.onlineFriends));
    final inGame = ref.watch(lobbyProvider.select((s) => s.playersConnected));
    final sent = ref.watch(lobbyProvider.select((s) => s.sentInvites));
    final gameId = ref.watch(lobbyProvider.select((s) => s.gameId));
    final requests = ref.watch(lobbyProvider.select((s) => s.friendRequests));
    final session = ref.read(sessionWebSocketProvider);

    // Online primero (alfabético), luego offline (alfabético).
    final onlineList = allFriends.where((f) => online.contains(f)).toList()..sort();
    final offlineList = allFriends.where((f) => !online.contains(f)).toList()..sort();
    final friends = [...onlineList, ...offlineList];

    return Padding(
      padding: EdgeInsets.all(w * 0.018),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: h * 0.07),

          Align(
            alignment: Alignment.centerLeft,
            child: RetroImgButton(
              label: 'Buscar jugadores',
              asset: 'assets/images/ui/btn_morado.png',
              width: w * 0.18,
              height: h * 0.06,
              fontSize: textSize * 0.85,
              onTap: () => showDialog(
                context: context,
                barrierColor: Colors.black87,
                builder: (_) => const FriendSearchModal(),
              ),
            ),
          ),

          SizedBox(height: h * 0.025),

          Text(
            'Amigos',
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: titleSize,
              color: Colors.white,
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 18),
                Shadow(color: Colors.white70, blurRadius: 8),
              ],
            ),
          ),

          SizedBox(height: h * 0.025),

          SizedBox(
            height: h * 0.45,
            child: (requests.isEmpty && friends.isEmpty)
                ? Text(
                    'No tienes amigos\naún',
                    style: TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: textSize * 0.85,
                      color: Colors.white38,
                      height: 1.4,
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Solicitudes de amistad pendientes.
                      if (requests.isNotEmpty) ...[
                        Text(
                          'Solicitudes',
                          style: TextStyle(
                            fontFamily: 'Retro Gaming',
                            fontSize: textSize * 0.8,
                            color: Colors.white54,
                          ),
                        ),
                        SizedBox(height: h * 0.010),
                        ...requests.map((from) => Padding(
                              padding: EdgeInsets.only(bottom: h * 0.012),
                              child: _FriendRequestRow(
                                username: from,
                                width: w * 0.30,
                                height: h * 0.050,
                                fontSize: textSize * 0.85,
                                onAccept: () => session.acceptFriendRequest(from),
                                onReject: () => session.rejectFriendRequest(from),
                              ),
                            )),
                        SizedBox(height: h * 0.015),
                      ],
                      // Lista de amigos (online primero, luego offline).
                      ...friends.map((username) {
                        final isOnline = online.contains(username);
                        final status = _resolveStatus(
                          username: username,
                          isOnline: isOnline,
                          inGame: inGame,
                          sent: sent,
                          hasActiveGame: gameId != null,
                        );
                        return Padding(
                          padding: EdgeInsets.only(bottom: h * 0.015),
                          child: _FriendRow(
                            username: username,
                            status: status,
                            nameWidth: w * 0.16,
                            chipWidth: w * 0.09,
                            chipHeight: h * 0.045,
                            fontSize: textSize * 0.85,
                            chipFontSize: textSize * 0.75,
                            onInvite: (status == _FriendChipStatus.invitar &&
                                    gameId != null)
                                ? () => session.inviteFriend(username, gameId)
                                : null,
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  _FriendChipStatus _resolveStatus({
    required String username,
    required bool isOnline,
    required List<String> inGame,
    required Set<String> sent,
    required bool hasActiveGame,
  }) {
    if (!isOnline) return _FriendChipStatus.offline;
    if (hasActiveGame && inGame.contains(username)) return _FriendChipStatus.contigo;
    if (hasActiveGame && sent.contains(username)) return _FriendChipStatus.invitado;
    return _FriendChipStatus.invitar;
  }
}

// Estados visuales del chip junto al nombre de un amigo en la lista.
enum _FriendChipStatus { contigo, invitado, invitar, offline }

// WIDGETS AUXILIARES
// Slot individual de jugador con fondo btn_morado.png.
// Muestra el nombre del jugador si el slot está ocupado, o "Vacío" si no.
// FittedBox garantiza que un nombre largo nunca desborde el contenedor.
class _PlayerSlot extends StatelessWidget {
  // Nombre a mostrar en el slot ("Vacío" si no hay jugador).
  final String name;
  // Indica si el slot tiene un jugador asignado.
  final bool filled;
  // Dimensiones del slot en píxeles, calculadas por el widget padre.
  final double width, height;
  // Tamaño de fuente base; FittedBox lo reducirá si el nombre es demasiado largo.
  final double fontSize;

  // Constructor de la clase, con parámetros requeridos.
  const _PlayerSlot({
    required this.name,
    required this.filled,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  // Metodo build que construye la UI del slot de jugador.
  @override
  Widget build(BuildContext context) {
    // Container es un widget de Flutter que permite crear un rectángulo con dimensiones
    // para añadir un asset de imagen.
    return Container(
      width: width,
      height: height,
      // alignment: Alignment.center es necesario para que el hijo quede centrado;
      // el valor por defecto de Container es Alignment.topLeft.
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // btn_verde cuando el slot tiene jugador, btn_morado cuando está vacío.
        // BoxFit.fill estira el asset para que cubra exactamente el contenedor.
        image: DecorationImage(
          image: AssetImage(filled
              ? 'assets/images/ui/btn_verde.png'
              : 'assets/images/ui/btn_morado.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Padding(
        // Padding horizontal para que el texto no toque los bordes del asset.
        padding: EdgeInsets.symmetric(horizontal: width * 0.08),
        child: FittedBox(
          // FittedBox.scaleDown reduce el texto si el nombre es muy largo,
          // pero nunca lo amplía por encima de su fontSize natural.
          fit: BoxFit.scaleDown,
          child: Text(
            name,
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: fontSize,
              color: Colors.white,
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 14),
                Shadow(color: Colors.white70, blurRadius: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Fila de la lista de amigos: nombre a la izquierda + chip de estado a la derecha.
// El chip reutiliza el estilo visual de los slots del lobby (btn_verde/rojo/morado)
// y solo el estado "Invitar" es interactivo.
class _FriendRow extends StatelessWidget {
  final String username;
  final _FriendChipStatus status;
  // Anchura reservada al nombre y al chip respectivamente.
  final double nameWidth, chipWidth, chipHeight;
  final double fontSize, chipFontSize;
  // Solo se pasa cuando status == invitar y hay partida activa.
  final VoidCallback? onInvite;

  const _FriendRow({
    required this.username,
    required this.status,
    required this.nameWidth,
    required this.chipWidth,
    required this.chipHeight,
    required this.fontSize,
    required this.chipFontSize,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: nameWidth,
          child: Text(
            username,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: fontSize,
              color: Colors.white,
              shadows: const [
                Shadow(color: Colors.white, blurRadius: 14),
                Shadow(color: Colors.white70, blurRadius: 6),
              ],
            ),
          ),
        ),
        const Spacer(),
        _FriendChip(
          status: status,
          width: chipWidth,
          height: chipHeight,
          fontSize: chipFontSize,
          onTap: status == _FriendChipStatus.invitar ? onInvite : null,
        ),
      ],
    );
  }
}

// Chip de estado para la lista de amigos. Reutiliza los mismos assets que los
// slots del panel central para mantener coherencia visual con el lobby:
//   - btn_verde => Contigo (no clickable)
//   - btn_rojo  => Invitado (no clickable)
//   - btn_morado => Invitar (clickable si onTap != null)
class _FriendChip extends StatelessWidget {
  final _FriendChipStatus status;
  final double width, height, fontSize;
  final VoidCallback? onTap;

  const _FriendChip({
    required this.status,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    late final String asset;
    late final String label;
    switch (status) {
      case _FriendChipStatus.contigo:
        asset = 'assets/images/ui/btn_verde.png';
        label = 'Contigo';
        break;
      case _FriendChipStatus.invitado:
        asset = 'assets/images/ui/btn_rojo.png';
        label = 'Invitado';
        break;
      case _FriendChipStatus.invitar:
        asset = 'assets/images/ui/btn_morado.png';
        label = 'Invitar';
        break;
      case _FriendChipStatus.offline:
        asset = 'assets/images/ui/btn_morado.png';
        label = 'Offline';
        break;
    }

    // Contigo e Invitado son informativos: no hacen nada al pulsar pero deben
    // mostrarse con opacidad completa. Se pasa un no-op para que RetroImgButton
    // no los oscurezca. Solo Offline usa onTap null (opacidad 45 %).
    final effectiveOnTap =
        (status == _FriendChipStatus.contigo || status == _FriendChipStatus.invitado)
            ? () {}
            : onTap;
    return RetroImgButton(
      label: label,
      asset: asset,
      width: width,
      height: height,
      fontSize: fontSize,
      onTap: effectiveOnTap,
    );
  }
}

// Fila para la lista de solicitudes de amistad entrantes: nombre del solicitante
// a la izquierda y dos botones (aceptar / rechazar) a la derecha.
// Fila de invitación a partida: muestra quién invita y el código de la partida,
// con botón "Unirse" (verde) e "Ignorar" (rojo).
class _GameInviteRow extends StatelessWidget {
  final GameInvite invite;
  final double width, height, fontSize;
  final VoidCallback onJoin;
  final VoidCallback onDismiss;

  const _GameInviteRow({
    required this.invite,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onJoin,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final btnW = height * 1.2;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  invite.fromUser,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: fontSize,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.white, blurRadius: 10),
                    ],
                  ),
                ),
                Text(
                  'Código: ${invite.gameId}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: fontSize * 0.75,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: height * 0.2),
          _IconRetroButton(
            asset: 'assets/images/ui/btn_verde.png',
            width: btnW,
            height: height,
            onTap: onJoin,
            child: _RetroCheckIcon(size: height * 0.55),
          ),
          SizedBox(width: height * 0.2),
          _IconRetroButton(
            asset: 'assets/images/ui/btn_rojo.png',
            child: Text('X', style: TextStyle(color: Colors.white, fontSize: height * 0.52, fontWeight: FontWeight.bold, fontFamily: 'Retro Gaming')),
            width: btnW,
            height: height,
            onTap: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _FriendRequestRow extends StatelessWidget {
  final String username;
  final double width, height, fontSize;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _FriendRequestRow({
    required this.username,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final btnW = height * 1.2;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: Text(
              username,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: fontSize,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Colors.white, blurRadius: 14),
                  Shadow(color: Colors.white70, blurRadius: 6),
                ],
              ),
            ),
          ),
          SizedBox(width: height * 0.2),
          // Botón aceptar: verde, con check dibujado.
          _IconRetroButton(
            asset: 'assets/images/ui/btn_verde.png',
            width: btnW,
            height: height,
            onTap: onAccept,
            child: _RetroCheckIcon(size: height * 0.55),
          ),
          SizedBox(width: height * 0.2),
          // Botón rechazar: rojo, con X.
          _IconRetroButton(
            asset: 'assets/images/ui/btn_rojo.png',
            width: btnW,
            height: height,
            onTap: onReject,
            child: Text('X', style: TextStyle(color: Colors.white, fontSize: height * 0.52, fontWeight: FontWeight.bold, fontFamily: 'Retro Gaming')),
          ),
        ],
      ),
    );
  }
}

// Botón pequeño con asset de fondo y un icono centrado.
// Pensado para las acciones aceptar/rechazar de las solicitudes de amistad.
class _IconRetroButton extends StatelessWidget {
  final String asset;
  final Widget child;
  final double width, height;
  final VoidCallback onTap;

  const _IconRetroButton({
    required this.asset,
    required this.child,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(asset),
            fit: BoxFit.fill,
          ),
        ),
        child: child,
      ),
    );
  }
}

// Iconos dibujados 

class _RetroGearIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _RetroGearIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GearPainter(color)),
      );
}

class _RetroLogoutIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _RetroLogoutIcon({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoutPainter(color)),
      );
}

class _RetroCheckIcon extends StatelessWidget {
  final double size;
  const _RetroCheckIcon({required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: const CustomPaint(painter: _CheckPainter(Colors.white)),
      );
}

class _GearPainter extends CustomPainter {
  final Color color;
  const _GearPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2, cy = s.height / 2, r = s.width / 2;
    const teeth = 7;
    final outer = r * 0.90, mid = r * 0.66, hole = r * 0.32;

    final gear = Path();
    for (int i = 0; i < teeth * 2; i++) {
      final a = (i * pi) / teeth - pi / 2;
      final rad = i.isEven ? outer : mid;
      final x = cx + rad * cos(a), y = cy + rad * sin(a);
      i == 0 ? gear.moveTo(x, y) : gear.lineTo(x, y);
    }
    gear.close();

    final holeP = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: hole));

    canvas.drawPath(
      Path.combine(PathOperation.difference, gear, holeP),
      Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_GearPainter o) => o.color != color;
}

class _LogoutPainter extends CustomPainter {
  final Color color;
  const _LogoutPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = s.width * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Marco de puerta (izq, arriba, abajo)
    final doorH = s.height * 0.68, top = s.height * 0.16;
    final left = s.width * 0.08, doorW = s.width * 0.42;
    canvas.drawPath(
      Path()
        ..moveTo(left + doorW, top)
        ..lineTo(left, top)
        ..lineTo(left, top + doorH)
        ..lineTo(left + doorW, top + doorH),
      p,
    );

    // Flecha →
    final ay = s.height / 2;
    final ax0 = left + doorW * 0.4, ax1 = s.width * 0.92;
    canvas.drawPath(Path()..moveTo(ax0, ay)..lineTo(ax1, ay), p);
    canvas.drawPath(
      Path()
        ..moveTo(ax1 - s.width * 0.22, ay - s.height * 0.20)
        ..lineTo(ax1, ay)
        ..lineTo(ax1 - s.width * 0.22, ay + s.height * 0.20),
      p,
    );
  }

  @override
  bool shouldRepaint(_LogoutPainter o) => o.color != color;
}

class _CheckPainter extends CustomPainter {
  final Color color;
  const _CheckPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawPath(
      Path()
        ..moveTo(s.width * 0.12, s.height * 0.50)
        ..lineTo(s.width * 0.40, s.height * 0.76)
        ..lineTo(s.width * 0.88, s.height * 0.24),
      Paint()
        ..color = color
        ..strokeWidth = s.width * 0.14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter o) => o.color != color;
}
