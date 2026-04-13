import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'minigame_base.dart';

// ============================================================
// Paso 2: Motor Lógico de Decodificación de Cartas
// ============================================================
class CartaInfo {
  final int valorOriginal;
  final String rango;
  final String iconoPalo;
  final Color color;

  const CartaInfo({
    required this.valorOriginal,
    required this.rango,
    required this.iconoPalo,
    required this.color,
  });

  factory CartaInfo.decodificar(int valor) {
    final int rangoVal = valor % 13;
    final int paloId = valor ~/ 13;

    String rango;
    switch (rangoVal) {
      case 0:
        rango = 'A';
        break;
      case 10:
        rango = 'J';
        break;
      case 11:
        rango = 'Q';
        break;
      case 12:
        rango = 'K';
        break;
      default:
        rango = (rangoVal + 1).toString();
    }

    String icono;
    Color colorCarta;
    switch (paloId) {
      case 0:
        icono = '♠️';
        colorCarta = Colors.black;
        break;
      case 1:
        icono = '♥️';
        colorCarta = const Color(0xFFD32F2F); // Rojo oscuro
        break;
      case 2:
        icono = '♣️';
        colorCarta = Colors.black;
        break;
      case 3:
        icono = '♦️';
        colorCarta = const Color(0xFFD32F2F); // Rojo oscuro
        break;
      default:
        icono = '♠️';
        colorCarta = Colors.black;
    }

    return CartaInfo(
      valorOriginal: valor,
      rango: rango,
      iconoPalo: icono,
      color: colorCarta,
    );
  }
}

// ============================================================
// Paso 1: Inicialización y Recepción de Datos
// ============================================================
class MayorMenorGame extends MinigameBase {
  const MayorMenorGame({
    super.key,
    required super.onFinish,
    required super.details,
  });

  @override
  State<MayorMenorGame> createState() => _MayorMenorGameState();
}

class _MayorMenorGameState extends State<MayorMenorGame> {
  late List<int> _cartasRaw;
  late String _personaje;

  int? _indiceSeleccionado;
  bool _juegoTerminado = false;

  @override
  void initState() {
    super.initState();

    // Extracción segura de la lista de cartas
    final listaCartas = widget.details['cartas'];
    if (listaCartas is List && listaCartas.length == 4) {
      _cartasRaw = List<int>.from(listaCartas);
    } else {
      // Fallback de seguridad en caso de que el backend envíe datos malformados
      _cartasRaw = [0, 13, 26, 39];
    }

    // Extracción del personaje (por defecto banquero si falla)
    _personaje = widget.details['personaje'] ?? 'banquero';
  }

  // ============================================================
  // Paso 7 & 8: Controlador de Interacción, Secuencia y Cierre
  // ============================================================
  void _seleccionarCarta(int index) {
    if (_indiceSeleccionado != null) return; // Bloqueo de concurrencia

    setState(() {
      _indiceSeleccionado = index;
    });
  }

  void _onAnimacionGiroCompletada() {
    if (!_juegoTerminado && _indiceSeleccionado != null) {
      setState(() {
        _juegoTerminado = true;
      });

      // Retraso de 2.5 segundos antes de notificar al backend
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          int valorBruto = _cartasRaw[_indiceSeleccionado!];
          // Calculamos el valor real de la carta (1 para A, 11 para J, 13 para K, etc.)
          int valorRealCarta = (valorBruto % 13) + 1;

          // Enviamos el valor real como score
          widget.onFinish(valorRealCarta);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ============================================================
          // Paso 3: Renderizado de la Capa Base (Fondo)
          // ============================================================
          Image.asset(
            'assets/images/minigames/cartas/fondo_cartas_${_personaje.toLowerCase()}.png',
            fit: BoxFit.cover,
            // Fallback silencioso a un color sólido si la imagen del personaje no existe
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF1B2A3B),
            ),
          ),

          // ============================================================
          // Paso 6: Ensamblaje del Tablero (Layout de Cartas)
          // ============================================================
          SafeArea(
            child: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                runSpacing: 24,
                children: List.generate(4, (index) {
                  return CartaWidget(
                    cartaInfo: CartaInfo.decodificar(_cartasRaw[index]),
                    seleccionada: _indiceSeleccionado == index,
                    onTap: () => _seleccionarCarta(index),
                    onAnimationComplete: _onAnimacionGiroCompletada,
                  );
                }),
              ),
            ),
          ),

          // ============================================================
          // Paso 8: Overlay destacado con el valor bruto
          // ============================================================
          if (_juegoTerminado && _indiceSeleccionado != null)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'VALOR REVELADO',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 24,
                          fontFamily: 'Retro Gaming',
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        // Mostramos el rango real (A, 2, 3... J, Q, K) usando tu propia clase
                        CartaInfo.decodificar(_cartasRaw[_indiceSeleccionado!])
                            .rango,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 96,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                                color: Colors.black,
                                blurRadius: 15,
                                offset: Offset(2, 4))
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Paso 4 & 5: Componente Visual de la Carta y Animación de Giro
// ============================================================
class CartaWidget extends StatefulWidget {
  final CartaInfo cartaInfo;
  final bool seleccionada;
  final VoidCallback onTap;
  final VoidCallback onAnimationComplete;

  const CartaWidget({
    super.key,
    required this.cartaInfo,
    required this.seleccionada,
    required this.onTap,
    required this.onAnimationComplete,
  });

  @override
  State<CartaWidget> createState() => _CartaWidgetState();
}

class _CartaWidgetState extends State<CartaWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animacionGiro;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animacionGiro = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
  }

  @override
  void didUpdateWidget(CartaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seleccionada && !oldWidget.seleccionada) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animacionGiro,
        builder: (context, child) {
          final isFront = _animacionGiro.value > (pi / 2);

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspectiva 3D
              ..rotateY(_animacionGiro.value),
            alignment: Alignment.center,
            child: isFront
                ? Transform(
                    // Inversión horizontal para evitar el efecto espejo
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildFront(),
                  )
                : _buildBack(),
          );
        },
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      width: 140,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(4, 4),
          )
        ],
        image: const DecorationImage(
          image:
              AssetImage('assets/images/minigames/cartas/carta_recortada.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildFront() {
    return Container(
      width: 140,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(2, 6),
          )
        ],
      ),
      child: Stack(
        children: [
          // Esquina superior izquierda
          Positioned(
            top: 8,
            left: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.cartaInfo.rango,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: widget.cartaInfo.color,
                  ),
                ),
                Text(
                  widget.cartaInfo.iconoPalo,
                  style: TextStyle(
                    fontSize: 18,
                    color: widget.cartaInfo.color,
                  ),
                ),
              ],
            ),
          ),

          // Centro
          Center(
            child: Text(
              widget.cartaInfo.iconoPalo,
              style: TextStyle(
                fontSize: 64,
                color: widget.cartaInfo.color,
              ),
            ),
          ),

          // Esquina inferior derecha (invertida)
          Positioned(
            bottom: 8,
            right: 8,
            child: RotatedBox(
              quarterTurns: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.cartaInfo.rango,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: widget.cartaInfo.color,
                    ),
                  ),
                  Text(
                    widget.cartaInfo.iconoPalo,
                    style: TextStyle(
                      fontSize: 18,
                      color: widget.cartaInfo.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
