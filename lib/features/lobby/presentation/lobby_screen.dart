import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/lobby_websocket_service.dart';
import 'controllers/lobby_provider.dart';
import '../../auth/presentation/controllers/auth_provider.dart';
import '../../../core/widgets/retro_widgets.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocus = FocusNode();

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _abandonarPartida() {
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
  }

  Future<void> _crearPartida() async {
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
    final token = ref.read(authProvider).token!;
    final success = await ref.read(lobbyProvider.notifier).crearPartida(token);
    if (success && mounted) {
      final gameId = ref.read(lobbyProvider).gameId!;
      ref.read(lobbyWebSocketProvider).connect(gameId, token);
    }
  }

  Future<void> _unirseConCodigo() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    final token = ref.read(authProvider).token!;
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).clearGameSession();
    final accepted =
        await ref.read(lobbyProvider.notifier).unirsePartida(code, token);
    if (accepted) {
      ref.read(lobbyWebSocketProvider).connect(code, token);
    }
  }

  Future<void> _logout() async {
    ref.read(lobbyWebSocketProvider).disconnect();
    ref.read(lobbyProvider.notifier).reset();
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LobbyState>(lobbyProvider, (prev, next) {
      if (prev != null &&
          !prev.allCharactersSelected &&
          next.allCharactersSelected) {
        ref.read(lobbyWebSocketProvider).disconnect();
        context.go('/game');
      }
      if (prev != null && !prev.forceDisconnected && next.forceDisconnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.serverMessage.isNotEmpty
                ? next.serverMessage
                : 'Sesión iniciada en otro dispositivo'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(lobbyProvider.notifier).clearForceDisconnected();
      }
      if (prev != null && next.error != null && next.error != prev.error) {
        final error = next.error!.toLowerCase();
        if (error.contains('autenticad') ||
            error.contains('unauthorized') ||
            error.contains('401')) {
          _logout();
        }
      }
    });

    final lobbyState = ref.watch(lobbyProvider);
    final username = ref.watch(authProvider).username ?? '';

    // Pantalla de selección de personaje (sin rediseño)
    if (lobbyState.gameId != null &&
        lobbyState.gameStarted &&
        !lobbyState.allCharactersSelected) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('Selección de personaje — $username',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: CharacterSelectionView(
            lobbyState: lobbyState, currentUsername: username),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Fondo ────────────────────────────────────────────────
          Image.asset('assets/images/ui/lobby.png', fit: BoxFit.cover),

          // ── Layout principal ─────────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Columna izquierda — 1/3 de pantalla
                SizedBox(
                  width: w * 0.33,
                  child: _LeftPanel(onLogout: _logout, w: w, h: h),
                ),
                // Columna central — 1/3 de pantalla
                SizedBox(
                  width: w * 0.34,
                  child: _CenterPanel(
                    lobbyState: lobbyState,
                    username: username,
                    codeController: _codeController,
                    codeFocus: _codeFocus,
                    onCrear: lobbyState.isLoading || lobbyState.gameId != null
                        ? null
                        : _crearPartida,
                    onUnirse: lobbyState.gameId != null ? null : _unirseConCodigo,
                    onAbandonar: _abandonarPartida,
                    w: w, h: h,
                  ),
                ),
                // Columna derecha — 1/3 de pantalla
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

// ═══════════════════════════════════════════════════════════════════
// COLUMNA IZQUIERDA
// ═══════════════════════════════════════════════════════════════════
class _LeftPanel extends StatelessWidget {
  final VoidCallback onLogout;
  final double w, h;

  const _LeftPanel({
    required this.onLogout,
    required this.w,
    required this.h,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = h * 0.042;
    final textSize = h * 0.020;

    return Padding(
      padding: EdgeInsets.all(w * 0.018),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Botón cerrar sesión ────────────────────────────────
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: onLogout,
              child: Icon(Icons.logout, color: Colors.white54, size: h * 0.030),
            ),
          ),

          SizedBox(height: h * 0.04),

          // ── Título sección ─────────────────────────────────────
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

// ═══════════════════════════════════════════════════════════════════
// COLUMNA CENTRAL
// ═══════════════════════════════════════════════════════════════════
class _CenterPanel extends StatelessWidget {
  final LobbyState lobbyState;
  final String username;
  final TextEditingController codeController;
  final FocusNode codeFocus;
  final VoidCallback? onCrear;
  final VoidCallback? onUnirse;
  final VoidCallback onAbandonar;
  final double w, h;

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

  // Construye la lista de 4 slots: el primero siempre muestra al usuario actual,
  // el resto muestra los demás jugadores conectados o "Vacío".
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

  @override
  Widget build(BuildContext context) {
    final titleSize = h * 0.042;
    final textSize = h * 0.026;
    final slotH = h * 0.058;
    final slotW = w * 0.088; // 3 slots caben en la columna central (w*0.34)
    final slots = _buildSlots();
    final slotGap = w * 0.010;
    final totalW = 3 * slotW + 2 * slotGap;
    final codeW = 2 * slotW + slotGap;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.015),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [

          const Spacer(flex: 15,),

          // ── Botón crear partida ─────────────────────────────────
          _RetroImgButton(
            label: lobbyState.isLoading ? '...' : 'Crear partida',
            asset: 'assets/images/ui/btn_morado.png',
            width: w * 0.21,
            height: h * 0.16,
            fontSize: titleSize * 0.85,
            onTap: onCrear,
          ),

          const Spacer(flex: 10,),

          // ── Bloque de slots alineados ───────────────────────────

          // Fila superior: código + slot0 (alineado con slot3)
          SizedBox(
            width: totalW,
            child: Row(
              children: [
                SizedBox(
                  width: codeW,
                  child: lobbyState.gameId != null
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
                      : Text(
                          'Crea una partida\npara obtener un código',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Retro Gaming',
                            fontSize: textSize * 0.75,
                            color: Colors.white38,
                            height: 1.4,
                          ),
                        ),
                ),
                SizedBox(width: slotGap),
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

          const Spacer(flex: 7),

          // Fila inferior: slots 1, 2, 3
          SizedBox(
            width: totalW,
            child: Row(
              children: [
                _PlayerSlot(name: slots[1] ?? 'Vacío', filled: slots[1] != null, width: slotW, height: slotH, fontSize: textSize * 0.72),
                SizedBox(width: slotGap),
                _PlayerSlot(name: slots[2] ?? 'Vacío', filled: slots[2] != null, width: slotW, height: slotH, fontSize: textSize * 0.72),
                SizedBox(width: slotGap),
                _PlayerSlot(name: slots[3] ?? 'Vacío', filled: slots[3] != null, width: slotW, height: slotH, fontSize: textSize * 0.72),
              ],
            ),
          ),

          // ── Botón abandonar y error (debajo de slots, pegados) ──
          if (lobbyState.gameId != null) ...[
            SizedBox(height: h * 0.012),
            _RetroImgButton(
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

          const Spacer(flex: 10,),

          // ── Sección unirse con código ───────────────────────────
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
          RetroField(
            label: '',
            controller: codeController,
            focusNode: codeFocus,
            fieldWidth: w * 0.20,
            fieldHeight: h * 0.075,
            labelFontSize: 0,
            inputFontSize: textSize,
            textInputAction: TextInputAction.done,
            onSubmitted: onUnirse,
          ),
          const Spacer(flex: 15),
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
          const Spacer(flex: 5),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// COLUMNA DERECHA
// ═══════════════════════════════════════════════════════════════════
class _RightPanel extends StatelessWidget {
  final double w, h;
  const _RightPanel({required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    final titleSize = h * 0.042;

    return Padding(
      padding: EdgeInsets.all(w * 0.018),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: h * 0.02),
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
          Text(
            'Próximamente...',
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: h * 0.018,
              color: Colors.white38,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  color: Colors.white54, size: h * 0.035),
              SizedBox(width: w * 0.005),
              Text(
                'Reglas',
                style: TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: h * 0.020,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          SizedBox(height: h * 0.02),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════

// Botón con imagen de fondo (btn_verde / btn_rojo)
class _RetroImgButton extends StatelessWidget {
  final String label;
  final String asset;
  final double width, height, fontSize;
  final VoidCallback? onTap;

  const _RetroImgButton({
    required this.label,
    required this.asset,
    required this.width,
    required this.height,
    required this.fontSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1.0,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(asset),
              fit: BoxFit.fill,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: fontSize,
                color: Colors.white,
                shadows: const [
                  Shadow(color: Colors.white, blurRadius: 14),
                  Shadow(color: Colors.white54, blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Slot de jugador con fondo btn_morado.png y texto blanco con brillo exterior
class _PlayerSlot extends StatelessWidget {
  final String name;
  final bool filled;
  final double width, height, fontSize;

  const _PlayerSlot({
    required this.name,
    required this.filled,
    required this.width,
    required this.height,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/ui/btn_morado.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: width * 0.08),
        child: FittedBox(
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

// ═══════════════════════════════════════════════════════════════════
// SELECCIÓN DE PERSONAJE (sin cambios visuales)
// ═══════════════════════════════════════════════════════════════════
class CharacterSelectionView extends ConsumerStatefulWidget {
  final LobbyState lobbyState;
  final String currentUsername;

  const CharacterSelectionView({
    super.key,
    required this.lobbyState,
    required this.currentUsername,
  });

  @override
  ConsumerState<CharacterSelectionView> createState() =>
      _CharacterSelectionViewState();
}

class _CharacterSelectionViewState
    extends ConsumerState<CharacterSelectionView> {
  final List<String> _availableCharacters = [
    'Banquero',
    'Videojugador',
    'Escapista',
    'Vidente'
  ];
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
          _timeLeft = 10;
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
    } else {
      jugadorActual = 'Esperando a los demás...';
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/images/board/tablero_def.png',
              fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Container(color: Colors.black.withValues(alpha:0.75)),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha:0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          _isMyTurn ? Colors.greenAccent : Colors.blueAccent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isMyTurn
                            ? '¡ES TU TURNO!'
                            : 'Turno de: $jugadorActual',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color:
                              _isMyTurn ? Colors.greenAccent : Colors.white,
                        ),
                      ),
                      if (_isMyTurn) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tiempo restante: $_timeLeft s',
                          style: const TextStyle(
                              fontSize: 20,
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold),
                        ),
                      ]
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
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

                      return Expanded(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              if (isTaken || !_isMyTurn) return;
                              _selectCharacter(character);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                color: isMySelection
                                    ? Colors.green.withValues(alpha:0.3)
                                    : (isTaken
                                        ? Colors.grey.withValues(alpha:0.5)
                                        : Colors.white.withValues(alpha:0.1)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMySelection
                                      ? Colors.greenAccent
                                      : (isTaken
                                          ? Colors.transparent
                                          : Colors.white54),
                                  width: 3,
                                ),
                                boxShadow: [
                                  if (isMySelection)
                                    const BoxShadow(
                                        color: Colors.greenAccent,
                                        blurRadius: 10,
                                        spreadRadius: 2)
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity:
                                            isTaken && !isMySelection ? 0.3 : 1.0,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 60.0),
                                          child: Image.asset(
                                            _getImageForCharacter(character),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        color: Colors.black.withValues(alpha:0.7),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        child: Column(
                                          children: [
                                            Text(
                                              character,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: isTaken && !isMySelection
                                                    ? Colors.grey
                                                    : Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            if (isTaken) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Elegido por $takenBy',
                                                style: const TextStyle(
                                                    color: Colors.redAccent,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                textAlign: TextAlign.center,
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
