import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/websocket_service.dart';
import '../../../../core/widgets/retro_widgets.dart';
import '../../../shop/data/shop_repository.dart';

class RuletaModal extends ConsumerStatefulWidget {
  final String itemName;
  final VoidCallback onClose;
  final bool isDebug;

  const RuletaModal({
    super.key,
    required this.itemName,
    required this.onClose,
    this.isDebug = false,
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
      case 'Avanzar Casillas':
        targetAngle = -pi / 4;
        break;
      case 'Mejorar Dados':
        targetAngle = -3 * pi / 4;
        break;
      case 'Barrera':
        targetAngle = -5 * pi / 4;
        break;
      case 'Salvavidas bloqueo':
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

      // Enviamos el mensaje al backend para que el ítem se añada al inventario
      // SOLO si no estamos en modo debug
      if (!widget.isDebug) {
        ref.read(webSocketProvider).sendGenericAction({
          'action': 'anyadir_objeto',
          'payload': {
            'objeto': widget.itemName
          }
        });
      }

      // Mostramos la pantalla de resultado tras 1 segundo
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _showResult = true;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 380,
      height: 560,
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
          'RUTA DE\nOBJETOS',
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
        const Text(
          'GIRA PARA CONSEGUIR UN ITEM DE LA TIENDA',
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 10,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 40),

        // Contenedor de la Ruleta
        SizedBox(
          width: 260,
          height: 260,
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
                      size: const Size(260, 260),
                      painter: _WheelPainter(),
                    ),
                    _buildSliceContent('AVANZAR\nCASILLAS', 'assets/images/items/item_avanzar.png', -pi / 4),
                    _buildSliceContent('MEJORAR\nDADOS', 'assets/images/items/item_dados.png', pi / 4),
                    _buildSliceContent('BARRERA', 'assets/images/items/item_barrera.png', 3 * pi / 4),
                    _buildSliceContent('SALVAVIDAS\nBLOQUEO', 'assets/images/items/item_salvavidas.png', 5 * pi / 4),
                  ],
                ),
              ),
              // Puntero naranja fijo arriba
              Positioned(
                top: -24,
                child: Column(
                  children: [
                    const Icon(Icons.arrow_drop_down,
                        color: Color(0xFFE65100), size: 60),
                    Container(
                      width: 10,
                      height: 10,
                      transform: Matrix4.translationValues(0, -15, 0),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        RetroImgButton(
          label: '¡GIRAR!',
          asset: 'assets/images/ui/btn_morado.png',
          width: 160,
          height: 52,
          fontSize: 16,
          onTap: (_isSpinning || _hasSpun) ? null : _spin,
        ),
        const SizedBox(height: 20),

        GestureDetector(
          onTap: (_isSpinning || _hasSpun) ? null : widget.onClose,
          child: const Text(
            'ABANDONAR',
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildResultContent() {
    final itemIcon = ShopRepository.catalog
        .firstWhere(
          (i) => i.name.toLowerCase() == widget.itemName.toLowerCase(),
          orElse: () => ShopRepository.catalog.first,
        )
        .icon;

    return Column(
      key: const ValueKey('result'),
      children: [
        const SizedBox(height: 40),
        const Text(
          '¡ENHORABUENA!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF5B922),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'HAS OBTENIDO UN OBJETO:',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 12,
            letterSpacing: 1.5,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 50),
        // Ícono del ítem
        Image.asset(
          itemIcon,
          height: 100,
          filterQuality: FilterQuality.none,
        ),
        const SizedBox(height: 40),
        // Nombre del ítem
        Text(
          widget.itemName.toUpperCase(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2.0,
          ),
        ),
        const Spacer(),
        RetroImgButton(
          label: 'ACEPTAR',
          asset: 'assets/images/ui/btn_morado.png',
          width: 200,
          height: 52,
          fontSize: 16,
          onTap: widget.onClose,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // Pinta el texto e iconos rotados mirando hacia el centro
  Widget _buildSliceContent(String text, String icon, double angle) {
    const double radius = 80;
    final double x = 130 + radius * cos(angle);
    final double y = 130 + radius * sin(angle);

    return Positioned(
      left: x - 40,
      top: y - 40,
      child: Transform.rotate(
        angle: angle + pi / 2, // Hace que la base del texto apunte al centro
        child: SizedBox(
          width: 80,
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(icon, height: 24, filterQuality: FilterQuality.none),
              const SizedBox(height: 4),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 8,
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

    // Amarillo (Arriba Izquierda)
    paint.color = const Color(0xFFFFF241);
    canvas.drawArc(rect, pi, pi / 2, true, paint);
    // Rojo (Arriba Derecha)
    paint.color = const Color(0xFFFF5252);
    canvas.drawArc(rect, -pi / 2, pi / 2, true, paint);
    // Verde (Abajo Derecha)
    paint.color = const Color(0xFF51FF52);
    canvas.drawArc(rect, 0, pi / 2, true, paint);
    // Azul (Abajo Izquierda)
    paint.color = const Color(0xFF5252FF);
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
