import 'dart:async';
import 'dart:math';

// Importa las dependencias necesarias para Flutter, Riverpod y navegación.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Importa los servicios y providers específicos del lobby, así como el provider de autenticación
import '../data/lobby_websocket_service.dart';
import 'controllers/lobby_provider.dart';
import '../../auth/presentation/controllers/auth_provider.dart';
import '../../../core/widgets/retro_widgets.dart';

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

  // Metodo privado para cerrar el WebSocket, resetear el estado del lobby y llamar al logout de auth,
  // lo que redirigirá automáticamente a la pantalla de login por el router.
  Future<void> _logout() async {
    ref.read(lobbyWebSocketProvider).disconnect();
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
    // muestra la pantalla de selección en lugar del lobby.
    if (lobbyState.gameId != null &&
        lobbyState.gameStarted &&
        !lobbyState.allCharactersSelected) {
      // Scaffold es un widget de Flutter que proporciona una estructura básica de pantalla con AppBar, body, etc.
      return Scaffold(
        // Para que la barra no tape el fondo.
        extendBodyBehindAppBar: true,
        // Fondo transparente para que se vea la imagen de lobby detrás.
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        // Mostamos la seleccion de personajes en si.
        body: CharacterSelectionView(
            lobbyState: lobbyState, currentUsername: username),
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
                // Columna central: crear partida, slots de jugadores y unirse por código.
                SizedBox(
                  width: w * 0.34,
                  child: _CenterPanel(
                    lobbyState: lobbyState,
                    username: username,
                    codeController: _codeController,
                    codeFocus: _codeFocus,
                    // Desactiva "Crear partida" mientras carga o ya hay una sala activa.
                    onCrear: lobbyState.isLoading || lobbyState.gameId != null
                        ? null
                        : _crearPartida,
                    // Desactiva "Unirse" si el jugador ya está en una sala.
                    onUnirse:
                        lobbyState.gameId != null ? null : _unirseConCodigo,
                    onAbandonar: _abandonarPartida,
                    w: w, h: h,
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
        ],
      ),
    );
  }
}

// COLUMNA IZQUIERDA
// Clase privada que define el panel lateral izquierdo con el botón de cerrar sesión y la sección
// de partidas de amigos (actualmente un placeholder).
class _LeftPanel extends StatelessWidget {
  // Callback que ejecuta el logout cuando el usuario pulsa el icono.
  final VoidCallback onLogout;
  // Dimensiones totales de la pantalla, usadas para calcular tamaños proporcionales.
  final double w, h;

  // Constructor de la clase.
  const _LeftPanel({
    required this.onLogout,
    required this.w,
    required this.h,
  });

  // Metodo que construye la UI del panel izquierdo.
  @override
  Widget build(BuildContext context) {
    // Tamaños de texto proporcionales al alto de la ventana.
    final titleSize = h * 0.042;
    final textSize = h * 0.020;

    // Padding es un widget de Flutter que añade espacio alrededor de su hijo.
    // En este caso, se usa un padding proporcional al ancho de la ventana.
    return Padding(
      // EdgeInsets añade un espacio de 1,8% del ancho de ventana por
      // cada lado del panel.
      padding: EdgeInsets.all(w * 0.018),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono de logout alineado a la derecha del panel.
          // Se usa Align en lugar de Row para no ocupar todo el ancho.
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: onLogout,
              child: Icon(Icons.logout, color: Colors.white54, size: h * 0.030),
            ),
          ),

          // Margen superior que baja el título para que no quede tapado
          // por el fondo decorativo de la imagen de lobby.
          SizedBox(height: h * 0.12),

          // Título de la sección con doble sombra blanca para efecto de brillo retro.
          Text(
            'Partidas de\namigos',
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

          // Texto provisional mientras no está implementada la funcionalidad.
          Text(
            'Próximamente...',
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: textSize * 0.85,
              color: Colors.white38,
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

// COLUMNA DERECHA
// Clase privada que representa el panel lateral derecho con la lista de amigos
// y el enlace a las reglas del juego en la parte inferior.
class _RightPanel extends StatelessWidget {
  // Dimensiones totales de la pantalla para calcular tamaños proporcionales.
  final double w, h;
  // Constructor de la clase, con parámetros requeridos para las dimensiones.
  const _RightPanel({required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    final titleSize = h * 0.042;
    // Padding horizontal para que el contenido no toque los bordes del panel.
    return Padding(
      padding: EdgeInsets.all(w * 0.018),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Margen superior para bajar el título y evitar que quede tapado
          // por el decorado superior de la imagen de lobby.
          SizedBox(height: h * 0.12),

          // Título de la sección con doble sombra blanca para efecto de brillo retro.
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

          // Texto provisional mientras la funcionalidad no está implementada.
          Text(
            'Próximamente...',
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: h * 0.018,
              color: Colors.white38,
            ),
          ),

          // Spacer empuja el botón de reglas hasta el fondo del panel.
          const Spacer(),

          // TODO: Enlace a las reglas del juego, anclado en la esquina inferior izquierda.
          SizedBox(height: h * 0.02),
        ],
      ),
    );
  }
}

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

// SELECCIÓN DE PERSONAJE (FALTA DE ADAPTAR A LA UI ACORDADA)
// Clase padre que define el estado de la vista de selección de personaje que se muestra cuando la partida ha comenzado
// pero todavía no todos los jugadores han elegido su personaje.
class CharacterSelectionView extends ConsumerStatefulWidget {
  // Estado del lobby con la lista de jugadores y los personajes ya seleccionados.
  final LobbyState lobbyState;
  // Nombre del usuario local para detectar cuándo es su turno.
  final String currentUsername;

  // Constructor de la clase, con parámetros requeridos.
  const CharacterSelectionView({
    super.key,
    required this.lobbyState,
    required this.currentUsername,
  });

  // Redefinición del método createState para asociar el estado mutable a esta vista
  // (tercer posible estado del lobby).
  @override
  ConsumerState<CharacterSelectionView> createState() =>
      _CharacterSelectionViewState();
}

// Clase privada que define el estado mutable de la vista de selección de personaje.
class _CharacterSelectionViewState
    extends ConsumerState<CharacterSelectionView> {
  final List<String> _availableCharacters = [
    'Banquero',
    'Videojugador',
    'Escapista',
    'Vidente'
  ];

  // Descripciones exactas del diseño original
  final Map<String, String> _descripciones = {
    'Banquero':
        'Roba una cantidad de\nmonedas X a un jugador\nelegido por el propio\nbanquero en cada turno.',
    'Videojugador': 'Vota entre dos opciones de\nminijuegos posibles.',
    'Escapista': 'Recibe penalizaciones\nreducidas en eventos\nnegativos.',
    'Vidente':
        'Puede visualizar el\nresultado de los dados\nantes de jugar el\nminijuego de orden para\ntomar decisiones\nestratégicas.',
  };

  Timer? _timer;
  int _timeLeft = 10;
  bool _isMyTurn = false;

  @override
  void initState() {
    super.initState();
    _checkTurnAndStartTimer();
  }

  @override
  void didUpdateWidget(CharacterSelectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lobbyState.selectedCharacters.length !=
        widget.lobbyState.selectedCharacters.length) {
      _checkTurnAndStartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkTurnAndStartTimer() {
    final numPersonajes = widget.lobbyState.selectedCharacters.length;
    final miOrden =
        widget.lobbyState.playersConnected.indexOf(widget.currentUsername) + 1;
    final ahoraEsMiTurno = (numPersonajes + 1) == miOrden;
    final yaHeSeleccionado = widget.lobbyState.selectedCharacters
        .containsKey(widget.currentUsername);

    if (ahoraEsMiTurno && !yaHeSeleccionado) {
      if (!_isMyTurn) {
        setState(() {
          _isMyTurn = true;
          _timeLeft =
              10; // Aunque no se muestre en el diseño, mantenemos la lógica por debajo
        });
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_timeLeft > 0) {
            setState(() => _timeLeft--);
          } else {
            timer.cancel();
            _autoSelectRandomCharacter();
          }
        });
      }
    } else {
      if (_isMyTurn) {
        setState(() => _isMyTurn = false);
        _timer?.cancel();
      }
    }
  }

  void _autoSelectRandomCharacter() {
    final takenCharacters =
        widget.lobbyState.selectedCharacters.values.toList();
    final remaining = _availableCharacters
        .where((c) => !takenCharacters.contains(c))
        .toList();
    if (remaining.isNotEmpty) {
      final randomChar = remaining[Random().nextInt(remaining.length)];
      ref.read(lobbyWebSocketProvider).sendCharacterSelection(randomChar);
    }
  }

  void _selectCharacter(String character) {
    if (!_isMyTurn) return;
    if (widget.lobbyState.selectedCharacters.containsValue(character)) return;
    _timer?.cancel();
    setState(() => _isMyTurn = false);
    ref.read(lobbyWebSocketProvider).sendCharacterSelection(character);
  }

  @override
  Widget build(BuildContext context) {
    final numPersonajes = widget.lobbyState.selectedCharacters.length;
    String jugadorActual = '';
    if (numPersonajes < widget.lobbyState.playersConnected.length) {
      jugadorActual = widget.lobbyState.playersConnected[numPersonajes];
    }

    // Colores fieles a la imagen proporcionada
    const bgColor = Color(0xFF291C49);
    const darkGreenBar = Color(0xFF10281F);
    const lightGreenBorder = Color(0xFF389354);
    const lightGreenText = Color(0xFF5ED18B);
    const inactiveBorder = Color(0xFF4A3E66);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- 1. CABECERA ----------------
            const SizedBox(height: 24),
            const Text(
              'SELECCIONA TU PERSONAJE',
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 28,
                color: Colors.white,
                letterSpacing: 3.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada héroe tiene habilidades únicas para dominar el tablero',
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),

            // ---------------- 2. BARRA DE ESTADO ----------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                color: darkGreenBar,
                border: Border(
                  top: BorderSide(color: lightGreenBorder, width: 2),
                  bottom: BorderSide(color: lightGreenBorder, width: 2),
                ),
              ),
              child: Text(
                _isMyTurn
                    ? 'ES TU TURNO DE ELEGIR'
                    : 'TURNO DE ELEGIR DE: ${jugadorActual.toUpperCase()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 14,
                  color: lightGreenText,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ---------------- 3. TARJETAS DE PERSONAJES ----------------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _availableCharacters.map((character) {
                    final isTaken = widget.lobbyState.selectedCharacters
                        .containsValue(character);
                    String takenBy = '';
                    if (isTaken) {
                      widget.lobbyState.selectedCharacters
                          .forEach((user, char) {
                        if (char == character) takenBy = user;
                      });
                    }

                    final isMySelection = takenBy == widget.currentUsername;
                    // La tarjeta activa brilla si está libre y es nuestro turno,
                    // o si fuimos nosotros quienes la elegimos.
                    final bool isActiveCard =
                        isMySelection || (_isMyTurn && !isTaken);
                    final bool canSelect = _isMyTurn && !isTaken;

                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 8.0),
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border.all(
                            color: isActiveCard ? Colors.white : inactiveBorder,
                            width: isActiveCard ? 3 : 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Recuadro del Avatar (Cara del personaje)
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: bgColor,
                                border: Border.all(
                                  color: isActiveCard
                                      ? Colors.white
                                      : inactiveBorder,
                                  width: isActiveCard ? 3 : 1.5,
                                ),
                              ),
                              // Usamos un factor de escala mayor y alineación precisa para centrar la cara
                              child: ClipRect(
                                child: Align(
                                  alignment: const Alignment(0.0, -0.85),
                                  heightFactor: 0.55,
                                  child: Opacity(
                                    opacity:
                                        (isTaken && !isMySelection) ? 0.3 : 1.0,
                                    child: Transform.scale(
                                      scale: 2.2,
                                      child: Image.asset(
                                        _getImageForCharacter(character),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Título de la tarjeta
                            Text(
                              character.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Retro Gaming',
                                fontSize: 16,
                                color: (isTaken && !isMySelection)
                                    ? Colors.white38
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Descripción de la habilidad
                            Expanded(
                              child: Text(
                                _descripciones[character]!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Retro Gaming',
                                  fontSize: 10,
                                  color: (isTaken && !isMySelection)
                                      ? Colors.white24
                                      : Colors.white70,
                                  height: 1.5,
                                ),
                              ),
                            ),

                            // Botón inferior
                            if (isTaken && !isMySelection)
                              // Diseño del botón cuando está inactivo/elegido por otro
                              Container(
                                width: double.infinity,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1435),
                                  border: Border.all(
                                      color: const Color(0xFF2A1D45),
                                      width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Elegido',
                                  style: TextStyle(
                                    fontFamily: 'Retro Gaming',
                                    color: Colors.white24,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            else if (isActiveCard)
                              // Diseño del botón ACTIVO con la textura solicitada
                              RetroImgButton(
                                label: isMySelection ? 'ELEGIDO' : 'Elegir',
                                asset: 'assets/images/ui/btn_verde.png',
                                width: double.infinity,
                                height: 42,
                                fontSize: 13,
                                onTap: canSelect
                                    ? () => _selectCharacter(character)
                                    : null,
                              )
                            else
                              // Diseño del botón atenuado cuando es turno de otro
                              Container(
                                width: double.infinity,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1435),
                                  border: Border.all(
                                      color: const Color(0xFF2A1D45),
                                      width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Elegir',
                                  style: TextStyle(
                                    fontFamily: 'Retro Gaming',
                                    color: Colors.white24,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ---------------- 4. FOOTER ----------------
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFF160E27),
            ),
            const SizedBox(height: 12),
            const Text(
              'ELIGE TU PERSONAJE PARA CONTINUAR...',
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 10,
                color: Colors.white38,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  String _getImageForCharacter(String character) {
    switch (character) {
      case 'Banquero':
        return 'assets/images/characters/general/banquero_frente_der.png';
      case 'Videojugador':
        return 'assets/images/characters/general/videojugador_frente_der.png';
      case 'Escapista':
        return 'assets/images/characters/general/escapista_frente_der.png';
      case 'Vidente':
        return 'assets/images/characters/general/vidente_frente_der.png';
      default:
        return 'assets/images/characters/general/banquero_frente_der.png';
    }
  }
}
