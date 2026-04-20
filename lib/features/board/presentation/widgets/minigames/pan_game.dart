import 'package:flutter/material.dart';
import '../../../../../core/widgets/retro_widgets.dart';
import 'minigame_base.dart';

enum PanState { active, finished }

class PanGame extends MinigameBase {
  const PanGame({
    super.key,
    required super.onFinish,
    required super.details,
  });

  @override
  State<PanGame> createState() => _PanGameState();
}

class _PanGameState extends State<PanGame> with SingleTickerProviderStateMixin {
  PanState _state = PanState.active;
  late AnimationController _controller;
  late Animation<Alignment> _animacionBarra;

  String _mensaje = "Pulsa CORTAR cuando estés listo";

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _animacionBarra = Tween<Alignment>(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).animate(_controller);

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCut() {
    if (_state != PanState.active) return;

    _controller.stop();

    double posicionX = _animacionBarra.value.x;
    double distanciaAlCentro = posicionX.abs();
    double porcentaje = ((posicionX + 1.0) / 2.0) * 100;

    setState(() {
      _state = PanState.finished;
      if (distanciaAlCentro < 0.05) {
        _mensaje = "Corte perfecto";
      } else if (distanciaAlCentro < 0.3) {
        _mensaje = "Corte decente";
      } else {
        _mensaje = "Mal corte";
      }
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) widget.onFinish(porcentaje.round());
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Fondo a pantalla completa
            Positioned.fill(
              child: Image.asset(
                'assets/images/minigames/pan/fondo.png',
                fit: BoxFit.cover,
              ),
            ),

            // Franja superior con título y línea amarilla inferior
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                    top: h * 0.03, bottom: h * 0.03),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFFFB800), width: 3),
                  ),
                ),
                child: Center(
                  child: Text(
                    '¡CORTA EL PAN!',
                    style: TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: h * 0.06,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: const [
                        Shadow(color: Colors.white, blurRadius: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Mensaje de resultado (sólo cuando ya se ha cortado)
            if (_state == PanState.finished)
              Positioned(
                top: h * 0.17,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    _mensaje,
                    style: TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: h * 0.04,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 6),
                      ],
                    ),
                  ),
                ),
              ),

            // Pan (un poco más pequeño)
            Positioned(
              top: h * 0.51,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  height: h * 0.25,
                  width: w * 0.42,
                  child: Image.asset(
                    'assets/images/minigames/pan/pan.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Línea guía de puntos en el centro del pan
            Positioned(
              top: h * 0.50,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 4,
                  height: h * 0.25,
                  child: CustomPaint(
                    painter: _DottedGuidePainter(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),

            // Línea de corte (cuchillo) — por encima del pan
            AnimatedBuilder(
              animation: _animacionBarra,
              builder: (context, child) {
                final panWidth = w * 0.4;
                final barX = (w / 2) + _animacionBarra.value.x * (panWidth / 2);
                return Positioned(
                  top: h * 0.25,
                  height: h * 0.55,
                  left: barX - 3,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.white,
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.white70,
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Botón CORTAR inferior
            Positioned(
              bottom: h * 0.08,
              left: 0,
              right: 0,
              child: Center(
                child: RetroImgButton(
                  label: 'CORTAR',
                  asset: 'assets/images/ui/btn_rojo.png',
                  width: w * 0.17,
                  height: h * 0.1,
                  fontSize: h * 0.035,
                  outlined: true,
                  onTap: _state == PanState.active ? _handleCut : null,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DottedGuidePainter extends CustomPainter {
  final Color color;
  _DottedGuidePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const dotRadius = 1.8;
    const gap = 7.0;
    double y = dotRadius;
    while (y < size.height) {
      canvas.drawCircle(Offset(size.width / 2, y), dotRadius, paint);
      y += gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedGuidePainter old) => old.color != color;
}
