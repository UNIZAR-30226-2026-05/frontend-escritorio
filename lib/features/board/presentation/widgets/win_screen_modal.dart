import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/retro_widgets.dart';
import '../../domain/gamemodels.dart';
import '../board_screen.dart';
import '../../data/websocket_service.dart';
import '../../../lobby/presentation/controllers/lobby_provider.dart';

class WinScreenModal extends ConsumerStatefulWidget {
  final List<Player> rankedPlayers;
  final VoidCallback? onClose;

  const WinScreenModal({
    super.key,
    required this.rankedPlayers,
    this.onClose,
  });

  @override
  ConsumerState<WinScreenModal> createState() => _WinScreenModalState();
}

class _WinScreenModalState extends ConsumerState<WinScreenModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rankedPlayers.isEmpty) return const SizedBox.shrink();
    final winner = widget.rankedPlayers.first;
    final others = widget.rankedPlayers.skip(1).toList();

    return Material(
      color: Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---------------- TÍTULO ----------------
              Text(
                '¡FIN DE LA PARTIDA!',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 60,
                  fontFamily: 'Retro Gaming',
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      offset: const Offset(4, 4),
                      blurRadius: 2,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // ---------------- CORONA FLOTANTE ----------------
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, sin(_controller.value * 2 * pi) * 8),
                    child: child,
                  );
                },
                child: const Text('👑', style: TextStyle(fontSize: 48)),
              ),

              // ---------------- SECCIÓN GANADOR ----------------
              Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Tarjeta del ganador
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1640),
                          border: Border.all(color: Colors.amber, width: 6),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.6),
                              blurRadius: 25,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Image.asset(
                              getCharacterPerfilPath(winner.characterClass),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      // Badge "1º LUGAR"
                      Positioned(
                        bottom: -15,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 4)
                            ],
                          ),
                          child: const Text(
                            '1º LUGAR',
                            style: TextStyle(
                              color: Colors.black,
                              fontFamily: 'Retro Gaming',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Nombre del Ganador
                  Text(
                    winner.username.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontFamily: 'Retro Gaming',
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 50),

              // ---------------- RANKING SECUNDARIO ----------------
              if (others.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: others.asMap().entries.map((entry) {
                      final idx = entry.key + 2; // 2nd, 3rd, 4th
                      final player = entry.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _buildRankingBox(idx, player),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 60),

              // ---------------- BOTÓN SALIR ----------------
              RetroImgButton(
                label: 'VOLVER AL MENÚ',
                asset: 'assets/images/ui/btn_morado.png',
                width: 240,
                height: 60,
                fontSize: 16,
                onTap: () {
                  if (widget.onClose != null) {
                    widget.onClose!();
                  } else {
                    ref.read(webSocketProvider).disconnect();
                    ref.read(lobbyProvider.notifier).clearGameSession();
                    context.go('/lobby');
                  }
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRankingBox(int place, Player player) {
    return Container(
      width: 260,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1640).withValues(alpha: 0.9),
        border: Border.all(color: Colors.white24, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Place Number
          Text(
            '$placeº',
            style: const TextStyle(
              color: Colors.white60,
              fontFamily: 'Retro Gaming',
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Avatar
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFF2D1B4E),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: Image.asset(
              getCharacterPerfilPath(player.characterClass),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              player.username.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Retro Gaming',
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
