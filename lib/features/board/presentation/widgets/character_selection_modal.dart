import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lobby/presentation/controllers/lobby_provider.dart';
import '../../../lobby/data/lobby_websocket_service.dart';

class CharacterSelectionModal extends ConsumerStatefulWidget {
  final LobbyState lobbyState;
  final String currentUsername;

  const CharacterSelectionModal({
    super.key,
    required this.lobbyState,
    required this.currentUsername,
  });

  @override
  ConsumerState<CharacterSelectionModal> createState() =>
      _CharacterSelectionModalState();
}

class _CharacterSelectionModalState
    extends ConsumerState<CharacterSelectionModal> {
  final List<String> _availableCharacters = [
    'Banquero',
    'Videojugador',
    'Escapista',
    'Vidente'
  ];

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
  void didUpdateWidget(CharacterSelectionModal oldWidget) {
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

  Widget _buildElegirButton({required String text, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/ui/btn_verde.png'),
            fit: BoxFit.fill,
          ),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 16,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = Colors.black,
              ),
            ),
            Text(
              text,
              style: const TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusLabel({
    required String text,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Retro Gaming',
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  String _getImageForCharacter(String character) {
    switch (character) {
      case 'Banquero':
        return 'assets/images/characters/general/banquero_perfil.png';
      case 'Videojugador':
        return 'assets/images/characters/general/videojugador_perfil.png';
      case 'Escapista':
        return 'assets/images/characters/general/escapista_perfil.png';
      case 'Vidente':
        return 'assets/images/characters/general/vidente_perfil.png';
      default:
        return 'assets/images/characters/general/banquero_perfil.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final numPersonajes = widget.lobbyState.selectedCharacters.length;
    final allChosen = numPersonajes >= widget.lobbyState.playersConnected.length;
    String jugadorActual = '';
    if (numPersonajes < widget.lobbyState.playersConnected.length) {
      jugadorActual = widget.lobbyState.playersConnected[numPersonajes];
    }

    // Colores fieles a la imagen proporcionada
    const mainBgColor = Color(0xFF2C2255); // Oscuro morado para el cuerpo
    const headerBgColor = Color(0xFF57468B); // Morado más claro cabecera
    const whiteLineColor = Colors.white;

    return Container(
      width: 1040,
      height: 640,
      decoration: BoxDecoration(
        color: mainBgColor,
        border: Border.all(color: Colors.white, width: 2), // Outer white border
      ),
      child: Column(
        children: [
          // ---------------- 1. CABECERA ----------------
          Container(
            width: double.infinity,
            color: headerBgColor,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: const Column(
              children: [
                Text(
                  'SELECCIONA TU PERSONAJE',
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: 28,
                    color: Colors.white,
                    letterSpacing: 4.0,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Cada héroe tiene habilidades únicas para dominar el tablero',
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // Linea separadora cabecera
          Container(height: 2, width: double.infinity, color: whiteLineColor),

          // ---------------- 2. BARRA DE ESTADO ----------------
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: allChosen
                  ? const Color(0xFF1E382B)
                  : _isMyTurn
                      ? const Color(0xFF1E382B).withValues(alpha: 0.6)
                      : const Color(0xFF382B1E), // Tono amarillento/marrón
              border: Border(
                bottom: BorderSide(
                  color: _isMyTurn ? const Color(0xFF3CD37D) : const Color(0xFFD3A03C),
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              allChosen
                  ? '✓ TODOS LOS JUGADORES HAN ELEGIDO'
                  : _isMyTurn
                      ? 'ES TU TURNO DE ELEGIR'
                      : 'ESPERANDO A: ${jugadorActual.toUpperCase()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 16,
                color: _isMyTurn ? const Color(0xFF6DE899) : const Color(0xFFE8D36D),
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // ---------------- 3. TARJETAS DE PERSONAJES ----------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _availableCharacters.map((character) {
                  final isUnavailable = widget.lobbyState.selectedCharacters
                      .containsValue(character);
                  String takenBy = '';
                  if (isUnavailable) {
                    widget.lobbyState.selectedCharacters.forEach((user, char) {
                      if (char == character) takenBy = user;
                    });
                  }

                  final isMySelection = takenBy == widget.currentUsername;
                  final bool isActiveCard =
                      isMySelection || (_isMyTurn && !isUnavailable);
                  final bool canSelect = _isMyTurn && !isUnavailable;

                  final bool dimCard = isUnavailable && !isMySelection;

                  return Expanded(
                    child: Opacity(
                      opacity: dimCard ? 0.4 : 1.0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 0),
                        padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
                        decoration: BoxDecoration(
                          color: mainBgColor,
                          border: Border.all(
                            color: isActiveCard ? Colors.white : Colors.white38,
                            width: isActiveCard ? 3 : 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Recuadro del Avatar (≈1/3 del alto de la tarjeta)
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1640),
                                border: Border.all(
                                  color: isActiveCard
                                      ? Colors.white
                                      : Colors.white38,
                                  width: isActiveCard ? 2 : 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Image.asset(
                                  _getImageForCharacter(character),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Título
                            Text(
                              character.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: 'Retro Gaming',
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Descripción
                            Expanded(
                              child: Text(
                                _descripciones[character]!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'Retro Gaming',
                                  fontSize: 12,
                                  color: Colors.white,
                                  height: 1.5,
                                ),
                              ),
                            ),

                            // Botón inferior / Estado
                            if (isUnavailable)
                              _buildStatusLabel(
                                text: 'OCUPADO',
                                bgColor: Colors.red.withValues(alpha: 0.2),
                                borderColor: Colors.redAccent,
                                textColor: Colors.redAccent,
                              )
                            else if (canSelect)
                              _buildElegirButton(
                                text: 'ELEGIR',
                                onTap: () => _selectCharacter(character),
                              )
                            else if (isMySelection)
                              _buildStatusLabel(
                                text: 'SELECCIONADO',
                                bgColor: Colors.green.withValues(alpha: 0.2),
                                borderColor: Colors.greenAccent,
                                textColor: Colors.greenAccent,
                              )
                            else
                              _buildStatusLabel(
                                text: 'ESPERA...',
                                bgColor: Colors.grey.withValues(alpha: 0.2),
                                borderColor: Colors.grey,
                                textColor: Colors.white54,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ---------------- 4. FOOTER ----------------
          Container(
              height: 2,
              width: double.infinity,
              color: Colors.white24),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(seconds: 1),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: child,
              );
            },
            onEnd: () {
              // No podemos forzar un rebuild aquí fácilmente sin setState, 
              // pero TweenAnimationBuilder puede reiniciarse si cambiamos el tween o usamos un Controller.
              // Para simplificar, usaremos un loop infinito si es posible o simplemente lo dejamos como está.
            },
            child: Text(
              _isMyTurn
                  ? 'ELIEGE TU PERSONAJE PARA CONTINUAR...'
                  : 'ESPERANDO A LOS DEMÁS JUGADORES...',
              style: const TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 11,
                color: Colors.white70,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
