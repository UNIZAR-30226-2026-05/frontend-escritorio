import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RuletaModal extends ConsumerStatefulWidget {
  final String itemName;
  final String playerName;
  final bool isLocalPlayer;
  final VoidCallback onClose;
  const RuletaModal({
    super.key,
    required this.itemName,
    required this.playerName,
    required this.isLocalPlayer,
    required this.onClose,
  });

  @override
  ConsumerState<RuletaModal> createState() => _RuletaModalState();
}

class _RuletaModalState extends ConsumerState<RuletaModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isSpinning = false;
  bool _hasSpun = false;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);

    // Girar automáticamente al abrirse
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _spin();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning || _hasSpun) return;
    setState(() {
      _isSpinning = true;
    });

    // Calculamos el ángulo objetivo para que el ítem seleccionado quede bajo el puntero
    double targetAngle = 0;
    switch (widget.itemName) {
      case '+3 Casillas':
        targetAngle = -pi / 4;
        break;
      case '-3 Monedas':
        targetAngle = -3 * pi / 4;
        break;
      case '+3 Monedas':
        targetAngle = -5 * pi / 4;
        break;
      case '-3 Casillas':
        targetAngle = -7 * pi / 4;
        break;
      default:
        targetAngle = -pi / 4;
    }

    // Da 5 vueltas completas antes de detenerse en el target
    double endAngle = (5 * 2 * pi) + targetAngle;

    _animation = Tween<double>(begin: 0, end: endAngle).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward().then((_) {
      setState(() {
        _isSpinning = false;
        _hasSpun = true;
      });

      // Ya no enviamos anyadir_objeto porque el backend aplica el efecto inmediatamente

      // Mostramos la pantalla de resultado tras 1 segundo
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _showResult = true;
          });

          // REVELADO: Ya sabemos el premio, permitimos el movimiento si lo hubiera

          // Cerramos el modal automáticamente tras mostrar el resultado 3 segundos
          Future.delayed(const Duration(milliseconds: 3000), () {
            if (mounted) {
              widget.onClose();
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 500,
      height: 640,
      decoration: BoxDecoration(
        color: const Color(0xFF141927), // Fondo azul oscuro
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFF5B922), width: 3), // Borde amarillo
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _showResult ? _buildResultContent() : _buildWheelContent(),
      ),
    );
  }

  Widget _buildWheelContent() {
    return Column(
      key: const ValueKey('wheel'),
      children: [
        const SizedBox(height: 30),
        const Text(
          'RULETA DE\nLA SUERTE',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF5B922),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.isLocalPlayer
              ? 'GIRANDO LA RULETA DE OBJETOS'
              : '${widget.playerName} ESTÁ GIRANDO LA RULETA',
          style: const TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 10,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 40),

        // Contenedor de la Ruleta
        SizedBox(
          width: 360,
          height: 360,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Ruleta giratoria
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _animation.value,
                    child: child,
                  );
                },
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(360, 360),
                      painter: _WheelPainter(),
                    ),
                    _buildSliceContent('+3\nCASILLAS', -pi / 4),
                    _buildSliceContent('-3\nMONEDAS', pi / 4),
                    _buildSliceContent('+3\nMONEDAS', 3 * pi / 4),
                    _buildSliceContent('-3\nCASILLAS', 5 * pi / 4),
                  ],
                ),
              ),
              // Puntero triangular fijo arriba que indica el premio
              const Positioned(
                top: -24,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CustomPaint(painter: _PointerPainter()),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),
        // Los botones se han eliminado porque la ruleta es automática
      ],
    );
  }

  bool get _isPositivePrize => widget.itemName.startsWith('+');

  Widget _buildResultContent() {
    final isPositive = _isPositivePrize;
    final accentColor =
        isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    String headline;
    if (widget.isLocalPlayer) {
      headline = isPositive ? '¡ENHORABUENA!' : '¡MALA SUERTE!';
    } else {
      final who = widget.playerName;
      headline =
          isPositive ? '¡$who está de suerte!' : '¡$who tiene mala suerte!';
    }

    return Column(
      key: const ValueKey('result'),
      children: [
        const SizedBox(height: 40),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor, width: 2),
          ),
          child: Text(
            widget.itemName.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: accentColor,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const Spacer(),
        const Text(
          'CERRANDO...',
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 10,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // Pinta el texto rotado mirando hacia el centro
  Widget _buildSliceContent(String text, double angle) {
    const double radius = 110;
    final double x = 180 + radius * cos(angle);
    final double y = 180 + radius * sin(angle);

    return Positioned(
      left: x - 50,
      top: y - 50,
      child: Transform.rotate(
        angle: angle + pi / 2, // Hace que la base del texto apunte al centro
        child: SizedBox(
          width: 100,
          height: 100,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Pintor personalizado para los 4 sectores de colores de la ruleta
class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()..style = PaintingStyle.fill;

    // Rojo (Arriba Izquierda: -3 CASILLAS)
    paint.color = const Color(0xFFFF5252);
    canvas.drawArc(rect, pi, pi / 2, true, paint);
    // Verde (Arriba Derecha: +3 CASILLAS)
    paint.color = const Color(0xFF51FF52);
    canvas.drawArc(rect, -pi / 2, pi / 2, true, paint);
    // Rojo (Abajo Derecha: -3 MONEDAS)
    paint.color = const Color(0xFFFF5252);
    canvas.drawArc(rect, 0, pi / 2, true, paint);
    // Verde (Abajo Izquierda: +3 MONEDAS)
    paint.color = const Color(0xFF51FF52);
    canvas.drawArc(rect, pi / 2, pi / 2, true, paint);

    // Círculo central oscuro
    paint.color = const Color(0xFF141927);
    canvas.drawCircle(rect.center, size.width * 0.12, paint);
    // Anillo naranja central
    paint.color = const Color(0xFFF5B922);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    canvas.drawCircle(rect.center, size.width * 0.12, paint);
    // Punto central marrón
    paint.color = const Color(0xFF5E4B25);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(rect.center, size.width * 0.03, paint);

    // Borde Exterior (para tapar los bordes de los arcos)
    paint.color = const Color(0xFF141927);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 10;
    canvas.drawCircle(rect.center, size.width / 2, paint);

    // Líneas separadoras
    paint.strokeWidth = 2;
    canvas.drawLine(Offset(size.width / 2, 5),
        Offset(size.width / 2, size.height - 5), paint);
    canvas.drawLine(Offset(5, size.height / 2),
        Offset(size.width - 5, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Triángulo apuntando hacia abajo (puntero de ruleta)
    final path = Path()
      ..moveTo(w / 2, h)       // vértice inferior (punta)
      ..lineTo(0, 0)            // esquina superior izquierda
      ..lineTo(w, 0)            // esquina superior derecha
      ..close();

    // Relleno rojo
    canvas.drawPath(path, Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.fill);

    // Borde negro
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
