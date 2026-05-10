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
                    color: Colors.purple.withValues(alpha: 0.5),
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
            width: 340,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1B38),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFF00FF), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF00FF).withValues(alpha: 0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "¿DOBLE O\nNADA?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Retro Gaming',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 32),

                // Selector de apuesta
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botón Menos (-)
                    RetroImgButton(
                      label: '-',
                      asset: 'assets/images/ui/btn_morado.png',
                      width: 52,
                      height: 52,
                      fontSize: 30,
                      onTap: (_enviado || _apuesta <= 0)
                          ? null
                          : () {
                              setState(() => _apuesta--);
                            },
                    ),
                    const SizedBox(width: 12),

                    // Cuadro de Apuesta
                    Container(
                      width: 120,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1128),
                        border: Border.all(color: Colors.white24, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "APUESTA",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'Retro Gaming',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "$_apuesta¢",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Retro Gaming',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Botón Más (+)
                    RetroImgButton(
                      label: '+',
                      asset: 'assets/images/ui/btn_morado.png',
                      width: 52,
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
                const SizedBox(height: 24),

                // Botón Acción
                RetroImgButton(
                  label: _apuesta == 0 ? 'PASAR' : 'APOSTAR $_apuesta¢',
                  asset: _apuesta == 0
                      ? 'assets/images/ui/btn_rojo.png'
                      : 'assets/images/ui/btn_verde.png',
                  width: 200,
                  height: 52,
                  fontSize: 16,
                  onTap: _enviado
                      ? null
                      : () {
                          setState(() => _enviado = true);
                          widget.onFinish(_apuesta);
                        },
                ),
                const SizedBox(height: 24),

                // Footer
                Text(
                  "TU SALDO: $maxCoins¢",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Retro Gaming',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _apuesta == 0
                      ? "PASAR NO CAMBIA TU BALANCE"
                      : "AJUSTA LA APUESTA Y CONFIRMA ABAJO",
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 8,
                    fontFamily: 'Retro Gaming',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
