import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'minigame_base.dart';
import '../../controllers/game_provider.dart';
import '../../../../auth/presentation/controllers/auth_provider.dart';
import '../../../../../core/widgets/retro_widgets.dart';

class DobleNadaGame extends MinigameBase {
  const DobleNadaGame(
      {super.key, required super.onFinish, required super.details});

  @override
  State<DobleNadaGame> createState() => _DobleNadaGameState();
}

class _DobleNadaGameState extends State<DobleNadaGame> {
  int _apuesta = 1;
  bool _enviado = false;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final myUsername = ref.watch(authProvider).username;
        final player = ref
            .watch(gameProvider)
            .players
            .firstWhere((p) => p.username == myUsername);
        final maxCoins = player.coins;

        // Si no tiene monedas, enviamos automáticamente 0 con el mismo estilo visual
        if (maxCoins <= 0) {
          if (!_enviado) {
            _enviado = true;
            Future.microtask(() => widget.onFinish(0));
          }
          return Center(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xDD2D1B4E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purpleAccent, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: const Text(
                "No tienes monedas para apostar.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Retro Gaming',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xDD2D1B4E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purpleAccent, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "DOBLE O NADA",
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Retro Gaming',
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Tus monedas: $maxCoins 🪙",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontFamily: 'Retro Gaming',
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  "Apuesta: $_apuesta 🪙",
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Retro Gaming',
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Botón Menos (-)
                    RetroImgButton(
                      label: '-',
                      asset: 'assets/images/ui/btn_morado.png',
                      width: 60,
                      height: 52,
                      fontSize: 30,
                      onTap: (_enviado || _apuesta <= 1)
                          ? null
                          : () {
                              setState(() => _apuesta--);
                            },
                    ),
                    const SizedBox(width: 20),

                    // Botón Jugar
                    RetroImgButton(
                      label: 'JUGAR',
                      asset: 'assets/images/ui/btn_verde.png',
                      width: 160,
                      height: 52,
                      fontSize: 16,
                      onTap: _enviado
                          ? null
                          : () {
                              setState(() => _enviado = true);
                              widget.onFinish(_apuesta);
                            },
                    ),
                    const SizedBox(width: 20),

                    // Botón Más (+)
                    RetroImgButton(
                      label: '+',
                      asset: 'assets/images/ui/btn_morado.png',
                      width: 60,
                      height: 52,
                      fontSize: 28,
                      onTap: (_enviado || _apuesta >= maxCoins)
                          ? null
                          : () {
                              setState(() => _apuesta++);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
