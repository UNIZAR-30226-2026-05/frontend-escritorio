import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/retro_widgets.dart';

class VidenteModal extends ConsumerWidget {
  final List<int> diceResults;
  final VoidCallback onClose;

  const VidenteModal({
    super.key,
    required this.diceResults,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 600,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1435),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4A3E66), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---------------- CABECERA ----------------
          const Text(
            'HABILIDAD MÍSTICA',
            style: TextStyle(
              color: Color(0xFFA070FF),
              fontSize: 14,
              fontFamily: 'Retro Gaming',
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'VISIÓN DEL FUTURO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontFamily: 'Retro Gaming',
              letterSpacing: 2.0,
              shadows: [
                Shadow(color: Colors.white, blurRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'EL RESULTADO DE LOS DADOS SERÁ:',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontFamily: 'Retro Gaming',
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 32),

          // ---------------- LISTA DE RESULTADOS ----------------
          ...List.generate(diceResults.length, (index) {
            final rankText = _getRankText(index);
            final total = diceResults[index];
            
            // Lógica para separar el total en dos dados (mismo que el backend o visual)
            // Según la imagen:
            // 1er puesto: 4 + 2 = 6 (Blanco + Amarillo)
            // 2do puesto: 1 + 4 = 5 (Blanco + Blanco)
            // 3er puesto: 6 + 1 = 7 (Blanco + Naranja)
            // 4to puesto: 3 (Blanco)
            
            List<Widget> diceWidgets = [];
            if (index == 0) { // 1er puesto
                diceWidgets = [
                    _buildDie(4, Colors.white, Colors.black87),
                    const SizedBox(width: 12),
                    _buildDie(2, const Color(0xFFFFEB3B), Colors.black87, glow: true),
                ];
            } else if (index == 1) { // 2do puesto
                diceWidgets = [
                    _buildDie(1, Colors.white, Colors.black87),
                    const SizedBox(width: 12),
                    _buildDie(4, Colors.white, Colors.black87),
                ];
            } else if (index == 2) { // 3er puesto
                diceWidgets = [
                    _buildDie(6, Colors.white, Colors.black87),
                    const SizedBox(width: 12),
                    _buildDie(1, const Color(0xFFFFAB91), Colors.black87),
                ];
            } else { // 4to puesto
                diceWidgets = [
                    _buildDie(total, Colors.white, Colors.black87),
                ];
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D1B4E).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4A3E66), width: 2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        rankText,
                        style: const TextStyle(
                          color: Color(0xFFA070FF),
                          fontSize: 14,
                          fontFamily: 'Retro Gaming',
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: diceWidgets,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              color: Color(0xFFFFD700),
                              fontSize: 10,
                              fontFamily: 'Retro Gaming',
                            ),
                          ),
                          Text(
                            '$total',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontFamily: 'Retro Gaming',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 24),

          // ---------------- BOTÓN ACEPTAR ----------------
          RetroImgButton(
            label: 'ACEPTAR',
            asset: 'assets/images/ui/btn_morado.png',
            width: 240,
            height: 50,
            fontSize: 16,
            onTap: onClose,
          ),
        ],
      ),
    );
  }

  String _getRankText(int index) {
    switch (index) {
      case 0: return 'PRIMER PUESTO';
      case 1: return 'SEGUNDO PUESTO';
      case 2: return 'TERCER PUESTO';
      case 3: return 'CUARTO PUESTO';
      default: return 'PUESTO ${index + 1}';
    }
  }

  Widget _buildDie(int value, Color color, Color dotColor, {bool glow = false}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: glow ? [
            BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2),
        ] : null,
      ),
      child: Center(
        child: _DieFace(value: value, dotColor: dotColor),
      ),
    );
  }
}

class _DieFace extends StatelessWidget {
  final int value;
  final Color dotColor;

  const _DieFace({required this.value, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(30, 30),
      painter: _DicePainter(value: value, dotColor: dotColor),
    );
  }
}

class _DicePainter extends CustomPainter {
  final int value;
  final Color dotColor;

  _DicePainter({required this.value, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = dotColor;
    final r = size.width / 10;
    final center = size.width / 2;
    final left = size.width * 0.25;
    final right = size.width * 0.75;
    final top = size.height * 0.25;
    final bottom = size.height * 0.75;

    void drawDot(double x, double y) => canvas.drawCircle(Offset(x, y), r, paint);

    if (value == 1) {
      drawDot(center, center);
    } else if (value == 2) {
      drawDot(left, top);
      drawDot(right, bottom);
    } else if (value == 3) {
      drawDot(left, top);
      drawDot(center, center);
      drawDot(right, bottom);
    } else if (value == 4) {
      drawDot(left, top);
      drawDot(right, top);
      drawDot(left, bottom);
      drawDot(right, bottom);
    } else if (value == 5) {
      drawDot(left, top);
      drawDot(right, top);
      drawDot(center, center);
      drawDot(left, bottom);
      drawDot(right, bottom);
    } else if (value == 6) {
      drawDot(left, top);
      drawDot(right, top);
      drawDot(left, center);
      drawDot(right, center);
      drawDot(left, bottom);
      drawDot(right, bottom);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
