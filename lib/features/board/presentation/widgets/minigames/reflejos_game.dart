import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'minigame_base.dart';

enum ReflejosState { waiting, active, finished, falseStart }

class ReflejosGame extends MinigameBase {
  const ReflejosGame({
    super.key,
    required super.onFinish,
    required super.details,
  });

  @override
  State<ReflejosGame> createState() => _ReflejosGameState();
}

class _ReflejosGameState extends State<ReflejosGame> {
  ReflejosState _state = ReflejosState.waiting;
  Timer? _activationTimer;
  DateTime? _activationTime;

  @override
  void initState() {
    super.initState();
    _startRandomTimer();
  }

  void _startRandomTimer() {
    // El backend envía el tiempo objetivo en ms ("objetivo") para que todos
    // los clientes se activen exactamente al mismo tiempo de forma coordinada.
    final int delayMs =
        widget.details['objetivo'] as int? ?? (2000 + Random().nextInt(4000));

    _activationTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      setState(() {
        _state = ReflejosState.active;
        _activationTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _activationTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_state == ReflejosState.waiting) {
      // Falta - ha clickado antes de tiempo
      _activationTimer?.cancel();
      setState(() => _state = ReflejosState.falseStart);

      // Manda una puntuación de penalización (9999ms, el backend lo ordena de menor a mayor)
      _finishGame(9999);
    } else if (_state == ReflejosState.active) {
      // Reacción exitosa
      final int reaction =
          DateTime.now().difference(_activationTime!).inMilliseconds;
      setState(() {
        _state = ReflejosState.finished;
      });

      // El backend ordena este minijuego de menor a mayor tiempo
      _finishGame(reaction);
    }
  }

  void _finishGame(int score) {
    // Damos 2 segundos para ver el resultado antes de salir
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        widget.onFinish(score);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Color circleColor;

    switch (_state) {
      case ReflejosState.waiting:
        circleColor = Colors.redAccent.shade700;
        break;
      case ReflejosState.active:
        circleColor = Colors.greenAccent.shade400;
        break;
      case ReflejosState.finished:
        circleColor = Colors.blueAccent.shade400;
        break;
      case ReflejosState.falseStart:
        circleColor = Colors.grey.shade800;
        break;
    }

    // Coordenadas del rectángulo gris en Fondo.png (2816x1536)
    // x=556, y=110, w=1710, h=934

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double screenW = constraints.maxWidth;
          final double screenH = constraints.maxHeight;

          // La imagen usa BoxFit.cover, así que calculamos cómo se escala
          const double imgAspect = 2816 / 1536;
          final double screenAspect = screenW / screenH;

          double scale;
          double offsetX = 0;
          double offsetY = 0;

          if (screenAspect > imgAspect) {
            // Pantalla más ancha → la imagen se escala por ancho
            scale = screenW / 2816;
            offsetY = (screenH - 1536 * scale) / 2;
          } else {
            // Pantalla más alta → la imagen se escala por alto
            scale = screenH / 1536;
            offsetX = (screenW - 2816 * scale) / 2;
          }

          final double rectLeft = offsetX + 556 * scale;
          final double rectTop = offsetY + 110 * scale;
          final double rectWidth = 1710 * scale;
          final double rectHeight = 934 * scale;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Imagen de fondo fija (se ve siempre)
              Image.asset(
                'assets/images/minigames/reflejos/Fondo.png',
                fit: BoxFit.cover,
                width: screenW,
                height: screenH,
              ),

              // 2. El rectángulo que cambia de color, posicionado exactamente sobre la pizarra
              Positioned(
                left: rectLeft,
                top: rectTop,
                width: rectWidth,
                height: rectHeight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    color: circleColor.withValues(alpha: 0.9),
                  ),
                ),
              ),

              // 3. Pingüinillos de espaldas mirando la pizarra
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    'assets/images/characters/general/pinguinillos_de_espaldas.png',
                    height: screenH * 0.75,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
