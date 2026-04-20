import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../../../core/widgets/retro_widgets.dart';
import 'minigame_base.dart';

enum CronometroState { active, finished }

class CronometroGame extends MinigameBase {
  const CronometroGame({
    super.key,
    required super.onFinish,
    required super.details,
  });

  @override
  State<CronometroGame> createState() => _CronometroGameState();
}

// Usamos TickerProviderStateMixin porque necesitamos controlar el reloj interno y la animación de la cortina
class _CronometroGameState extends State<CronometroGame>
    with TickerProviderStateMixin {
  CronometroState _state = CronometroState.active;

  // Herramientas para el cronómetro exacto
  late Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();

  // Controlador para la animación de la cortina
  late AnimationController _cortinaController;
  late Animation<Offset> _animacionCortina;

  int _objetivoSec = 8; // Valor por defecto por si falla el backend
  String _mensajeResultado = "";

  @override
  void initState() {
    super.initState();

    // 1. Obtener el objetivo del backend (ej. 7, 8, 9 o 10)
    _objetivoSec = widget.details["objetivo"] ?? 8;

    // 2. Configurar la animación de la cortina (0.5 segundos de duración)
    _cortinaController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Animación que mueve la cortina desde arriba (fuera de vista) hacia abajo (cubriendo el centro)
    _animacionCortina = Tween<Offset>(
      begin: const Offset(0.0, -1.0), // Arriba
      end: const Offset(0.0, 0.0), // Posición final cubriendo el reloj
    ).animate(CurvedAnimation(
      parent: _cortinaController,
      curve: Curves.easeOut,
    ));

    // 3. Iniciar el reloj de alta precisión de Flutter
    _ticker = createTicker((elapsed) {
      if (_stopwatch.isRunning) {
        setState(() {
          // Si pasamos los 2.5 segundos (2500 ms) y la cortina no ha bajado, la bajamos
          if (_stopwatch.elapsedMilliseconds >= 2500 &&
              !_cortinaController.isAnimating &&
              !_cortinaController.isCompleted) {
            _cortinaController.forward();
          }
        });
      }
    });

    _stopwatch.start();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cortinaController.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  void _pararCronometro() {
    if (_state == CronometroState.active) {
      _stopwatch.stop();
      _ticker.stop();

      // Abrir la cortina para mostrar el resultado al jugador
      _cortinaController.reverse();

      int elapsedMs = _stopwatch.elapsedMilliseconds;
      int objetivoMs = _objetivoSec * 1000;

      // Calculamos cuánto se ha equivocado (en milisegundos)
      int errorMs = (elapsedMs - objetivoMs).abs();

      // TRUCO PARA EL BACKEND:
      // Enviamos (Objetivo + Error). Como el backend hace abs(Score - Objetivo),
      // el resultado final en el servidor será exactamente el Error. ¡El que tenga menor error gana!
      int scoreParaBackend = _objetivoSec + errorMs;

      setState(() {
        _state = CronometroState.finished;

        // Feedback para el usuario
        if (errorMs < 100) {
          _mensajeResultado = "¡CLAVADO! 🎯";
        } else if (errorMs < 500) {
          _mensajeResultado = "¡Muy cerca!";
        } else if (elapsedMs < objetivoMs) {
          _mensajeResultado = "Te precipitaste...";
        } else {
          _mensajeResultado = "Demasiado tarde...";
        }
      });

      _finishGame(scoreParaBackend);
    }
  }

  void _finishGame(int score) {
    // Dar 3 segundos para ver el resultado y el tiempo exacto antes de salir
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        widget.onFinish(score);
      }
    });
  }

  // Función auxiliar para formatear el texto del cronómetro (ej: 05.42)
  String get _tiempoFormateado {
    int millis = _stopwatch.elapsedMilliseconds;
    double seconds = millis / 1000;
    // padLeft asegura que siempre haya 2 ceros iniciales si es menor a 10
    String secondsStr = seconds.truncate().toString().padLeft(2, '0');
    // Nos quedamos con los dos primeros decimales
    String fractionStr =
        (millis % 1000).toString().padLeft(3, '0').substring(0, 2);
    return "$secondsStr.$fractionStr";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.black, // Fondo negro por si las imágenes no cubren todo
      body: Stack(
        children: [
          // Fondo, reloj y cortina escalados juntos
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: SizedBox(
                width: 1506,
                height: 901,
                child: Stack(
                  children: [
                    // 1. FONDO (El Búnker nevado)
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/minigames/cronometro/fondo.png',
                        fit: BoxFit.fill,
                      ),
                    ),

                    // 2. TEXTO DEL CRONÓMETRO (Se dibuja detrás de la cortina)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 40),
                        child: Text(
                          _tiempoFormateado,
                          style: const TextStyle(
                            fontFamily: 'Courier', // Fuente tipo reloj digital
                            fontSize:
                                100, // Aumentado proporcionalmente al nuevo fondo
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                            letterSpacing: 2.0,
                            shadows: [
                              Shadow(
                                  color: Colors.green,
                                  blurRadius: 10,
                                  offset: Offset(0, 0))
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 3. LA CORTINA (Persiana metálica animada)
                    Positioned(
                      left: 466,
                      top: 368,
                      width: 560,
                      height: 315,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                        child: SlideTransition(
                          position: _animacionCortina,
                          child: Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(
                                    'assets/images/minigames/cronometro/cortina.png'),
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. INTERFAZ SUPERIOR E INFERIOR (Textos y Botones)
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Arriba: Tiempo Objetivo
                Padding(
                  padding: const EdgeInsets.only(top: 30.0),
                  child: Center(
                    child: Text(
                      "TIEMPO OBJETIVO: 0$_objetivoSec:00",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Retro Gaming',
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFC107),
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Centro: Mensaje de resultado (solo visible al terminar)
                if (_state == CronometroState.finished)
                  Text(
                    _mensajeResultado,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),

                // Abajo: Botón Rosa de Parar
                Padding(
                  padding: const EdgeInsets.only(bottom: 60.0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: RetroImgButton(
                      label: "PARAR",
                      asset: 'assets/images/ui/btn_rojo.png',
                      width: 240,
                      height: 60,
                      fontSize: 24,
                      onTap: _pararCronometro,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
