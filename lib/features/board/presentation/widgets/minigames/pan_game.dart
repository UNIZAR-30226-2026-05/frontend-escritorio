import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
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

  String _mensaje = "Toca la pantalla para cortar";

  @override
  void initState() {
    super.initState();

    // Configurar el controlador de tiempo
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Velocidad de la barra
    );

    // Mapear el tiempo (0.0 a 1.0) a posiciones en la pantalla (-1.0 a 1.0 en X)
    _animacionBarra = Tween<Alignment>(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).animate(_controller);

    // Iniciar el movimiento de ida y vuelta
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleTap() {
    if (_state == PanState.active) {
      // Detener la barra
      _controller.stop();

      // Ver dónde está la barra. El centro es X = 0.0
      double posicionX = _animacionBarra.value.x;
      double distanciaAlCentro = posicionX.abs();

      // Utilizar porcentaje en lugar de posición para el resultado
      double porcentaje = ((posicionX + 1.0) / 2.0) * 100;
      setState(() {
        _state = PanState.finished;

        // Calcular lo bien que se ha hecho
        // TODO: cambiar los mensajes para que sean igual a web
        if (distanciaAlCentro < 0.05) {
          _mensaje = "Corte perfecto";
        } else if (distanciaAlCentro < 0.3) {
          _mensaje = "Corte decente";
        } else {
          _mensaje = "Mal corte";
        }
      });

      // El backend ordena este minijuego de menor a mayor distancia
      // Hay que restarla para que el de menor distancia tenga mayor puntaje
      _finishGame(porcentaje.round());
    }
  }

  void _finishGame(int score) {
    // Dar 2 segundos para ver el resultado antes de salir
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        widget.onFinish(score);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Cubrir toda la pantalla para que el usuario pueda tocar donde sea
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(title: const Text('Corta el Pan')),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/minigames/pan/fondo.png'),
              fit: BoxFit.cover, // Para que el fondo cubra toda la pantalla
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_mensaje,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color:
                          Colors.white)), // Cambiado color texto para contraste
              const SizedBox(height: 100),

              // Contenedor del pan
              Center(
                // Envolvemos en Center para asegurarnos de que quede en medio
                child: Container(
                  height: 160, // Pan alto
                  width: 340, // Pan ancho
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/minigames/pan/pan.png'),
                      fit: BoxFit.contain, // Evitamos que se estire
                    ),
                  ),
                  child: Stack(
                    // 3. ¡MUY IMPORTANTE! Permite que el cuchillo sobresalga del contenedor
                    clipBehavior: Clip.none,
                    children: [
                      // Línea guía del centro
                      const Align(
                        alignment: Alignment.center,
                        child: VerticalDivider(
                            color: Colors.white70,
                            thickness: 2,
                            width:
                                20 // Le damos algo de ancho al divisor para que se centre bien
                            ),
                      ),

                      // La barra movible (El cuchillo)
                      AnimatedBuilder(
                        animation: _animacionBarra,
                        builder: (context, child) {
                          return Align(
                            alignment: _animacionBarra.value,
                            // Usamos un FractionalOffset en el Y para mantenerlo centrado verticalmente
                            heightFactor: 1.0,
                            child: Container(
                              width: 6,
                              height:
                                  130, // 2. ¡El cuchillo es más alto (130) que el pan (80)!
                              decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(
                                      3), // Bordes redondeados al cuchillo
                                  boxShadow: [
                                    // Una pequeña sombra para que parezca que está flotando sobre el pan
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 4,
                                      offset: const Offset(2, 2),
                                    )
                                  ]),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
