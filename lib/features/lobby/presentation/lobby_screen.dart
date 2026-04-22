import 'dart:async';

// Importa las dependencias necesarias para Flutter, Riverpod y navegación.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importa los servicios y providers específicos del lobby, así como el provider de autenticación
import '../data/lobby_websocket_service.dart';
import '../data/session_websocket_service.dart';
import 'controllers/lobby_provider.dart';
import '../../auth/presentation/controllers/auth_provider.dart';
import '../../../core/widgets/retro_widgets.dart';
import '../../board/presentation/widgets/character_selection_modal.dart';
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
  final TextEditingController _currentPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();
  final FocusNode _currentPassFocus = FocusNode();
  final FocusNode _newPassFocus = FocusNode();
  final FocusNode _confirmPassFocus = FocusNode();

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
        ref
            .read(sessionWebSocketProvider)
            .connect(auth.username!, auth.token!);
      }
    });
  }

  // Metodo de limpieza que se llama al destruir el widget.
  @override
  void dispose() {
    // Cierra el WS de sesión al salir del lobby para evitar fugas de conexión.
    ref.read(sessionWebSocketProvider).disconnect();
    // Libera los recursos del controlador y el foco cuando el widget se destruye.
    _codeController.dispose();
    _codeFocus.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _currentPassFocus.dispose();
    _newPassFocus.dispose();
    _confirmPassFocus.dispose();
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
      // Al recibir una nueva invitación de partida muestra la notificación
      // tipo SnackBar con el username del remitente y el código para unirse.
      if (next.lastInvite != null &&
          (prev == null || prev.lastInvite != next.lastInvite)) {
        final invite = next.lastInvite!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2D1B4E),
            duration: const Duration(seconds: 6),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡${invite.fromUser} te ha invitado!',
                  style: const TextStyle(
                    fontFamily: 'Retro Gaming',
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Únete con el código: ${invite.gameId}',
                  style: const TextStyle(
                    fontFamily: 'Retro Gaming',
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Copiar',
              textColor: Colors.amberAccent,
              onPressed: () {
                _codeController.text = invite.gameId;
              },
            ),
          ),
        );
        ref.read(lobbyProvider.notifier).clearLastInvite();
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
                  child: _LeftPanel(onLogout: _logout, w: w, h: h),
                ),
                // Columna central: crear partida / cambiar contraseña.
                SizedBox(
                  width: w * 0.34,
                  child: _showPasswordChange
                      ? _PasswordChangePanel(
                          w: w,
                          h: h,
                          currentPassCtrl: _currentPassCtrl,
                          newPassCtrl: _newPassCtrl,
                          confirmPassCtrl: _confirmPassCtrl,
                          currentPassFocus: _currentPassFocus,
                          newPassFocus: _newPassFocus,
                          confirmPassFocus: _confirmPassFocus,
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

          // Botón engranaje "Cambiar Contraseña" (esquina inferior izquierda)
          Positioned(
            left: 10,
            bottom: 10,
            child: GestureDetector(
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
                child: const Text(
                  '⚙️',
                  style: TextStyle(fontSize: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// COLUMNA IZQUIERDA
// Muestra el icono de logout y la lista de solicitudes de amistad pendientes.
// Cada solicitud se puede aceptar o rechazar desde aquí; las acciones se envían
// al WS de sesión y se eliminan localmente de forma optimista.
class _LeftPanel extends ConsumerWidget {
  final VoidCallback onLogout;
  final double w, h;

  const _LeftPanel({
    required this.onLogout,
    required this.w,
    required this.h,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleSize = h * 0.042;
    final textSize = h * 0.020;
    final requests = ref.watch(
      lobbyProvider.select((s) => s.friendRequests),
    );
    final session = ref.read(sessionWebSocketProvider);

    return Padding(
      padding: EdgeInsets.all(w * 0.018),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono de logout alineado a la derecha del panel.
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: onLogout,
              child: Icon(Icons.logout, color: Colors.white54, size: h * 0.030),
            ),
          ),

          // Margen superior para que el título no quede tapado por el marco.
          SizedBox(height: h * 0.12),

          // Título retro con doble sombra blanca.
          Text(
            'Solicitudes\nde amistad',
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

          // Si no hay solicitudes pendientes mostramos un texto guía; si hay,
          // una lista scrollable con aceptar/rechazar por cada solicitud.
          Expanded(
            child: requests.isEmpty
                ? Text(
                    'No tienes solicitudes\npendientes',
                    style: TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: textSize * 0.85,
                      color: Colors.white38,
                      height: 1.4,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => SizedBox(height: h * 0.015),
                    itemBuilder: (context, i) {
                      final from = requests[i];
                      return _FriendRequestRow(
                        username: from,
                        width: w * 0.30,
                        height: h * 0.055,
                        fontSize: textSize * 0.9,
                        onAccept: () => session.acceptFriendRequest(from),
                        onReject: () => session.rejectFriendRequest(from),
                      );
                    },
                  ),
          ),

          // Formulario inferior para enviar una solicitud de amistad a un
          // username concreto. Sirve para poder probar el flujo de solicitudes
          // desde el propio lobby sin herramientas externas.
          _AddFriendForm(
            width: w * 0.30,
            height: h * 0.055,
            fontSize: textSize * 0.9,
            onSend: session.sendFriendRequest,
          ),
          SizedBox(height: h * 0.015),
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
// Muestra tres campos de contraseña y un botón de guardar, con un enlace
// "VOLVER AL MENÚ" para regresar al panel central normal.
class _PasswordChangePanel extends StatelessWidget {
  final double w, h;
  final TextEditingController currentPassCtrl;
  final TextEditingController newPassCtrl;
  final TextEditingController confirmPassCtrl;
  final FocusNode currentPassFocus;
  final FocusNode newPassFocus;
  final FocusNode confirmPassFocus;
  final VoidCallback onBack;

  const _PasswordChangePanel({
    required this.w,
    required this.h,
    required this.currentPassCtrl,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.currentPassFocus,
    required this.newPassFocus,
    required this.confirmPassFocus,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = h * 0.042;
    final textSize = h * 0.026;
    final fieldW = w * 0.23;
    final fieldH = h * 0.075;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.015),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          const Spacer(flex: 12),

          // Título
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

          // Campo: Contraseña actual
          RetroField(
            label: 'CONTRASEÑA ACTUAL',
            controller: currentPassCtrl,
            focusNode: currentPassFocus,
            fieldWidth: fieldW,
            fieldHeight: fieldH,
            labelFontSize: textSize * 0.7,
            inputFontSize: textSize * 0.9,
            obscureText: true,
            color: Colors.white,
            textInputAction: TextInputAction.next,
            onSubmitted: () =>
                FocusScope.of(context).requestFocus(newPassFocus),
          ),

          const Spacer(flex: 4),

          // Campo: Nueva contraseña
          RetroField(
            label: 'NUEVA CONTRASEÑA',
            controller: newPassCtrl,
            focusNode: newPassFocus,
            fieldWidth: fieldW,
            fieldHeight: fieldH,
            labelFontSize: textSize * 0.7,
            inputFontSize: textSize * 0.9,
            obscureText: true,
            color: Colors.white,
            textInputAction: TextInputAction.next,
            onSubmitted: () =>
                FocusScope.of(context).requestFocus(confirmPassFocus),
          ),

          const Spacer(flex: 4),

          // Campo: Confirmar nueva
          RetroField(
            label: 'CONFIRMAR NUEVA',
            controller: confirmPassCtrl,
            focusNode: confirmPassFocus,
            fieldWidth: fieldW,
            fieldHeight: fieldH,
            labelFontSize: textSize * 0.7,
            inputFontSize: textSize * 0.9,
            obscureText: true,
            color: Colors.white,
            textInputAction: TextInputAction.done,
            onSubmitted: () {
              // TODO: Integración real con backend
              onBack();
            },
          ),

          const Spacer(flex: 6),

          // Botón Guardar
          RetroImgButton(
            label: 'Guardar',
            asset: 'assets/images/ui/btn_verde.png',
            width: w * 0.15,
            height: h * 0.08,
            fontSize: titleSize * 0.65,
            onTap: () {
              // TODO: Integración real con backend
              onBack();
            },
          ),

          const Spacer(flex: 4),

          // Enlace volver al menú
          GestureDetector(
            onTap: onBack,
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
// Muestra la lista de amigos actualmente ONLINE con un chip de estado por cada uno:
//   - Contigo (verde): el amigo ya está en la partida local.
//   - Invitado (rojo): se le ha enviado una invitación desde esta partida.
//   - Invitar (morado): clickable, envía invite_friend por el WS de sesión.
// Si no hay partida activa, todos los amigos se muestran con el chip "Invitar"
// deshabilitado, porque no hay gameId al que invitar.
class _RightPanel extends ConsumerWidget {
  final double w, h;
  const _RightPanel({required this.w, required this.h});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final titleSize = h * 0.042;
    final textSize = h * 0.020;

    // select evita reconstrucciones del panel ante cambios irrelevantes del estado.
    final online = ref.watch(lobbyProvider.select((s) => s.onlineFriends));
    final inGame = ref.watch(lobbyProvider.select((s) => s.playersConnected));
    final sent = ref.watch(lobbyProvider.select((s) => s.sentInvites));
    final gameId = ref.watch(lobbyProvider.select((s) => s.gameId));
    final session = ref.read(sessionWebSocketProvider);

    // Orden alfabético estable para que la lista no baile entre updates.
    final friends = online.toList()..sort();

    return Padding(
      padding: EdgeInsets.all(w * 0.018),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: h * 0.12),

          // Título retro con doble sombra blanca.
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

          Expanded(
            child: friends.isEmpty
                ? Text(
                    'Ninguno de tus\namigos está online',
                    style: TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: textSize * 0.85,
                      color: Colors.white38,
                      height: 1.4,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: friends.length,
                    separatorBuilder: (_, __) => SizedBox(height: h * 0.015),
                    itemBuilder: (context, i) {
                      final username = friends[i];
                      final status = _resolveStatus(
                        username: username,
                        inGame: inGame,
                        sent: sent,
                        hasActiveGame: gameId != null,
                      );
                      return _FriendRow(
                        username: username,
                        status: status,
                        nameWidth: w * 0.16,
                        chipWidth: w * 0.09,
                        chipHeight: h * 0.045,
                        fontSize: textSize * 0.85,
                        chipFontSize: textSize * 0.75,
                        onInvite: status == _FriendChipStatus.invitar
                            ? () => session.inviteFriend(username, gameId!)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Decide qué chip mostrar junto al nombre del amigo según:
  //  1. Si ya está en la partida local => Contigo.
  //  2. Si le hemos invitado desde esta partida => Invitado.
  //  3. En otro caso => Invitar (solo habilitado si hay partida activa).
  _FriendChipStatus _resolveStatus({
    required String username,
    required List<String> inGame,
    required Set<String> sent,
    required bool hasActiveGame,
  }) {
    if (hasActiveGame && inGame.contains(username)) {
      return _FriendChipStatus.contigo;
    }
    if (hasActiveGame && sent.contains(username)) {
      return _FriendChipStatus.invitado;
    }
    return _FriendChipStatus.invitar;
  }
}

// Estados visuales del chip junto al nombre de un amigo en la lista.
enum _FriendChipStatus { contigo, invitado, invitar }

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
    }

    // RetroImgButton ya se encarga de bajar la opacidad cuando onTap es null,
    // así que el mismo botón sirve tanto para el estado clickable ("Invitar"
    // con partida activa) como para los informativos ("Contigo" / "Invitado")
    // y también para "Invitar" desactivado si no hay partida en curso.
    return RetroImgButton(
      label: label,
      asset: asset,
      width: width,
      height: height,
      fontSize: fontSize,
      onTap: onTap,
    );
  }
}

// Fila para la lista de solicitudes de amistad entrantes: nombre del solicitante
// a la izquierda y dos botones (aceptar / rechazar) a la derecha.
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
          // Botón aceptar: verde, con check.
          _IconRetroButton(
            asset: 'assets/images/ui/btn_verde.png',
            icon: Icons.check,
            width: btnW,
            height: height,
            onTap: onAccept,
          ),
          SizedBox(width: height * 0.2),
          // Botón rechazar: rojo, con aspa.
          _IconRetroButton(
            asset: 'assets/images/ui/btn_rojo.png',
            icon: Icons.close,
            width: btnW,
            height: height,
            onTap: onReject,
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
  final IconData icon;
  final double width, height;
  final VoidCallback onTap;

  const _IconRetroButton({
    required this.asset,
    required this.icon,
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
        child: Icon(icon, color: Colors.white, size: height * 0.55),
      ),
    );
  }
}

// Formulario compacto para enviar una solicitud de amistad a un username.
// Es Stateful porque mantiene su propio TextEditingController asociado al campo
// de entrada, sin obligar al panel padre a gestionar focos/controladores.
// Al enviar, limpia el campo y muestra un SnackBar informativo.
class _AddFriendForm extends StatefulWidget {
  final double width, height, fontSize;
  // Callback que envía la solicitud al backend a través del WS de sesión.
  final void Function(String playerId) onSend;

  const _AddFriendForm({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onSend,
  });

  @override
  State<_AddFriendForm> createState() => _AddFriendFormState();
}

class _AddFriendFormState extends State<_AddFriendForm> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final target = _ctrl.text.trim();
    if (target.isEmpty) return;
    widget.onSend(target);
    // Feedback al usuario y limpieza del campo para poder encadenar pruebas.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Solicitud enviada a $target'),
        duration: const Duration(seconds: 2),
      ),
    );
    _ctrl.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    // Botón compacto a la derecha del input con el asset verde y un icono "+".
    final btnW = widget.height * 1.2;
    return SizedBox(
      width: widget.width,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: widget.height,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/ui/rellenable.png'),
                  fit: BoxFit.fill,
                ),
              ),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: widget.width * 0.04),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: widget.fontSize,
                  color: Colors.black,
                ),
                cursorColor: const Color(0xFF6B21A8),
                decoration: InputDecoration(
                  hintText: 'username',
                  hintStyle: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: widget.fontSize * 0.9,
                    color: Colors.black45,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
          SizedBox(width: widget.height * 0.2),
          _IconRetroButton(
            asset: 'assets/images/ui/btn_verde.png',
            icon: Icons.person_add,
            width: btnW,
            height: widget.height,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
