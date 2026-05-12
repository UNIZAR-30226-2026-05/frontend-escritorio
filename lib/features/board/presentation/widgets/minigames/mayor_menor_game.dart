import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/game_provider.dart';
import '../../../../auth/presentation/controllers/auth_provider.dart';

// Motor de decodificación de cartas
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
        colorCarta = const Color(0xFFD32F2F);
        break;
      case 2:
        icono = '♣️';
        colorCarta = Colors.black;
        break;
      case 3:
        icono = '♦️';
        colorCarta = const Color(0xFFD32F2F);
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

// Inicialización y recepción de datos
class MayorMenorGame extends ConsumerStatefulWidget {
  const MayorMenorGame({
    super.key,
    required this.onFinish,
    required this.details,
  });

  final void Function(dynamic score) onFinish;
  final Map<String, dynamic> details;

  @override
  ConsumerState<MayorMenorGame> createState() => _MayorMenorGameState();
}

class _MayorMenorGameState extends ConsumerState<MayorMenorGame> {
  late List<int> _cartasRaw;

  // Índice de la carta asignada a este jugador según su posición en el orden de turno.
  // Se recalcula en cada build() para garantizar que turnOrder ya está poblado.
  int _assignedIndex = 0;

  int? _indiceSeleccionado;
  bool _juegoTerminado = false;

  @override
  void initState() {
    super.initState();

    final listaCartas = widget.details['cartas'];
    if (listaCartas is List && listaCartas.length == 4) {
      _cartasRaw = List<int>.from(listaCartas);
    } else {
      _cartasRaw = [0, 13, 26, 39];
    }

  }

  // Controlador de interacción, secuencia y cierre
  void _seleccionarCarta(int index) {
    if (_indiceSeleccionado != null) return;
    setState(() {
      _indiceSeleccionado = index;
    });
  }

  void _onAnimacionGiroCompletada() {
    if (!_juegoTerminado && _indiceSeleccionado != null) {
      setState(() {
        _juegoTerminado = true;
      });

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          // Siempre usamos la carta asignada al jugador, no la que tocó visualmente
          final int valorBruto = _cartasRaw[_assignedIndex];
          final int valorRealCarta = (valorBruto % 13) + 1;
          widget.onFinish(valorRealCarta);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = ref.watch(authProvider).username;

    // Recalculamos el índice asignado de forma reactiva para asegurar que
    // turnOrder ya está poblado cuando el minijuego se renderiza.
    final turnOrder = ref.watch(gameProvider.select((s) => s.turnOrder));
    final pos = turnOrder.indexOf(myUsername ?? '');
    _assignedIndex = (pos >= 0 ? pos : 0).clamp(0, _cartasRaw.length - 1);

    final player = ref
        .watch(gameProvider)
        .players
        .firstWhere((p) => p.username == myUsername);
    final personajeLocal = player.characterClass.name.toLowerCase();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Renderizado de la capa base (el fondo)
          Image.asset(
            'assets/images/minigames/cartas/fondo_cartas_$personajeLocal.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF1B2A3B),
            ),
          ),

          // Ensamblaje del Tablero (Layout de Cartas)
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final bool haySeleccion = _indiceSeleccionado != null;
                    final bool esNoSeleccionada =
                        haySeleccion && _indiceSeleccionado != index;
                    final bool esSeleccionada = _indiceSeleccionado == index;

                    // La carta visual (dorso) es la del índice de posición.
                    // La carta que se revela al girar es siempre la asignada.
                    final CartaInfo cartaAMostrar = esSeleccionada
                        ? CartaInfo.decodificar(_cartasRaw[_assignedIndex])
                        : CartaInfo.decodificar(_cartasRaw[index]);

                    return Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: index == 0 || index == 3 ? 0 : 32),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: esNoSeleccionada ? 0.5 : 1.0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 300),
                          scale: esNoSeleccionada ? 0.85 : 1.0,
                          curve: Curves.easeOut,
                          child: CartaWidget(
                            cartaInfo: cartaAMostrar,
                            seleccionada: esSeleccionada,
                            onTap: () => _seleccionarCarta(index),
                            onAnimationComplete: _onAnimacionGiroCompletada,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Componente Visual de la Carta y Animación de Giro
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
      duration: const Duration(milliseconds: 800),
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
              ..setEntry(3, 2, 0.001)
              ..rotateY(_animacionGiro.value),
            alignment: Alignment.center,
            child: isFront
                ? Transform(
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
      width: 180,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
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
    final int paloId = widget.cartaInfo.valorOriginal ~/ 13;
    final int rangoVal = widget.cartaInfo.valorOriginal % 13;

    const List<String> palos = ['spades', 'hearts', 'clubs', 'diamonds'];
    final String palo = palos[paloId.clamp(0, 3)];
    final int numero = rangoVal + 1;

    final String assetPath =
        'assets/images/minigames/cartas/cards/card_${palo}_$numero.png';

    return Container(
      width: 180,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(2, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          assetPath,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
        ),
      ),
    );
  }
}
