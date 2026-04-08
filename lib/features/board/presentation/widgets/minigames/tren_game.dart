import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'minigame_base.dart';

enum _TrenState { waiting, passing, choosing, finished }

class TrenGame extends MinigameBase {
  const TrenGame({
    super.key,
    required super.onFinish,
    required super.details,
  });

  @override
  State<TrenGame> createState() => _TrenGameState();
}

class _TrenGameState extends State<TrenGame>
    with SingleTickerProviderStateMixin {
  _TrenState _state = _TrenState.waiting;
  late AnimationController _trainCtrl;
  late Animation<double> _trainPos; // fracción de ancho de pantalla

  late int _objetivo;
  late List<int> _options;
  late List<List<bool>> _wagonSeats; // pre-calculado para no cambiar por rebuild

  int? _userGuess;
  Timer? _choiceTimer;
  int _timeLeft = 15;

  static const int _numWagons = 3;
  static const int _seatsPerWagon = 8; // 2 filas x 4 columnas

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _objetivo = widget.details['objetivo'] as int? ?? 10;
    _options = _generateOptions(_objetivo, rng);
    _wagonSeats = _distributePassengers(_objetivo, rng);

    // El tren cruza la pantalla en 3 s (empieza fuera por la izquierda,
    // termina fuera por la derecha).
    _trainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _trainPos = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _trainCtrl, curve: Curves.linear),
    );

    // El tren arranca 1,5 s después de montar el widget.
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _state = _TrenState.passing);
      _trainCtrl.forward();
    });

    _trainCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _state = _TrenState.choosing);
        _startChoiceTimer();
      }
    });
  }

  @override
  void dispose() {
    _trainCtrl.dispose();
    _choiceTimer?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  // Helpers de datos
  // ──────────────────────────────────────────────

  List<int> _generateOptions(int real, Random rng) {
    final Set<int> opts = {real};
    // Candidatos: ±2, ±3, ±5 del real, mezclados
    final offsets = [-5, -3, -2, 2, 3, 5]..shuffle(rng);
    for (final o in offsets) {
      if (opts.length >= 4) break;
      final v = max(1, real + o);
      opts.add(v);
    }
    // Relleno por si acaso
    int extra = 1;
    while (opts.length < 4) {
      opts.add(max(1, real + extra++));
    }
    return opts.toList()..shuffle(rng);
  }

  /// Reparte _objetivo pasajeros entre los vagones y fija qué asientos están ocupados.
  List<List<bool>> _distributePassengers(int total, Random rng) {
    // Reparto aleatorio entre vagones
    final counts = List.filled(_numWagons, 0);
    int remaining = total.clamp(0, _seatsPerWagon * _numWagons);
    for (int i = 0; i < _numWagons - 1 && remaining > 0; i++) {
      final max = min(remaining, _seatsPerWagon);
      counts[i] = rng.nextInt(max + 1);
      remaining -= counts[i];
    }
    counts[_numWagons - 1] = remaining;

    // Para cada vagón: lista de asientos ocupados (aleatorizado)
    return counts.map((n) {
      final seats = List.generate(_seatsPerWagon, (i) => i < n);
      seats.shuffle(rng);
      return seats;
    }).toList();
  }

  // ──────────────────────────────────────────────
  // Lógica de selección
  // ──────────────────────────────────────────────

  void _startChoiceTimer() {
    _choiceTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        // Tiempo agotado → selección automática de una opción al azar
        _onSelect(_options[Random().nextInt(_options.length)]);
      }
    });
  }

  void _onSelect(int guess) {
    if (_state != _TrenState.choosing) return;
    _choiceTimer?.cancel();
    setState(() {
      _userGuess = guess;
      _state = _TrenState.finished;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onFinish(guess);
    });
  }

  // ──────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(w, h),
            _buildTracks(w, h),
            if (_state == _TrenState.passing ||
                _state == _TrenState.waiting)
              _buildAnimatedTrain(w, h),
            if (_state == _TrenState.waiting)
              _buildWarning(h),
            if (_state == _TrenState.choosing ||
                _state == _TrenState.finished)
              _buildChoicePanel(h),
          ],
        );
      },
    );
  }

  // ── Fondo degradado (cielo + campo) ──
  Widget _buildBackground(double w, double h) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.60, 0.60, 1.0],
          colors: [
            Color(0xFF0D1B2A), // cielo oscuro
            Color(0xFF1B2A3B),
            Color(0xFF3B5E3A), // campo
            Color(0xFF2E4A2E),
          ],
        ),
      ),
    );
  }

  // ── Raíles ──
  Widget _buildTracks(double w, double h) {
    return Positioned(
      left: 0,
      right: 0,
      top: h * 0.58,
      height: h * 0.12,
      child: CustomPaint(painter: _TrackPainter()),
    );
  }

  // ── Tren animado ──
  Widget _buildAnimatedTrain(double w, double h) {
    final wagonH = h * 0.32;
    final locoW = wagonH * 1.4;
    final wagonW = wagonH * 2.0;
    final totalW = locoW + wagonW * _numWagons + (_numWagons + 1) * 6.0;

    return AnimatedBuilder(
      animation: _trainPos,
      builder: (_, __) {
        final left = _trainPos.value * w - totalW / 2;
        return Positioned(
          left: left,
          top: h * 0.30,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildLocomotive(locoW, wagonH),
              ...List.generate(_numWagons, (i) =>
                  _buildWagon(wagonW, wagonH, _wagonSeats[i])),
            ],
          ),
        );
      },
    );
  }

  // ── Locomotora ──
  Widget _buildLocomotive(double w, double h) {
    return Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFC62828),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(6),
        ),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Chimenea
          Positioned(
            left: w * 0.18,
            top: -h * 0.18,
            child: Container(
              width: w * 0.14,
              height: h * 0.22,
              decoration: const BoxDecoration(
                color: Color(0xFF424242),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
          // Ventana del maquinista
          Positioned(
            right: w * 0.06,
            top: h * 0.12,
            child: Container(
              width: w * 0.28,
              height: h * 0.32,
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent.withValues(alpha: 0.55),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
            ),
          ),
          // Ruedas
          Positioned(
            bottom: -h * 0.09,
            left: 0,
            right: 0,
            child: _buildWheelRow(w, h * 0.18),
          ),
        ],
      ),
    );
  }

  // ── Vagón con pasajeros ──
  Widget _buildWagon(double w, double h, List<bool> seats) {
    return Container(
      width: w,
      height: h,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ventanas con pasajeros
          Padding(
            padding: EdgeInsets.fromLTRB(
                w * 0.06, h * 0.08, w * 0.06, h * 0.22),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              children: seats.map((occupied) {
                return Container(
                  decoration: BoxDecoration(
                    color: occupied
                        ? const Color(0xFFFFCC02)
                        : Colors.white.withValues(alpha: 0.12),
                    border:
                        Border.all(color: Colors.black45, width: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: occupied
                      ? const Icon(Icons.person,
                          size: 10, color: Colors.black87)
                      : null,
                );
              }).toList(),
            ),
          ),
          // Franja inferior
          Positioned(
            bottom: h * 0.08,
            left: 0,
            right: 0,
            child: Container(
              height: h * 0.06,
              color: const Color(0xFF0D47A1),
            ),
          ),
          // Ruedas
          Positioned(
            bottom: -h * 0.09,
            left: 0,
            right: 0,
            child: _buildWheelRow(w, h * 0.16),
          ),
        ],
      ),
    );
  }

  Widget _buildWheelRow(double w, double wheelSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildWheel(wheelSize),
        _buildWheel(wheelSize),
      ],
    );
  }

  Widget _buildWheel(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF212121),
        border: Border.all(color: Colors.grey.shade600, width: 2),
      ),
      child: Center(
        child: Container(
          width: size * 0.3,
          height: size * 0.3,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  // ── Aviso de espera ──
  Widget _buildWarning(double h) {
    return Center(
      child: Text(
        '¡El tren está llegando!\nPrepárate para contar los pasajeros...',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.amber,
          fontSize: h * 0.038,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
    );
  }

  // ── Panel de elección ──
  Widget _buildChoicePanel(double h) {
    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿CUÁNTOS PASAJEROS VISTE?',
              style: TextStyle(
                color: Colors.amber,
                fontSize: h * 0.042,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            if (_state == _TrenState.choosing)
              Text(
                'Tiempo: $_timeLeft s',
                style: TextStyle(
                  color: _timeLeft <= 5 ? Colors.redAccent : Colors.white60,
                  fontSize: h * 0.028,
                ),
              ),
            SizedBox(height: h * 0.04),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: _options.map((opt) {
                Color bg = const Color(0xFF1565C0);
                if (_state == _TrenState.finished) {
                  if (opt == _objetivo) {
                    bg = Colors.green;
                  } else if (opt == _userGuess) {
                    bg = Colors.red;
                  }
                }
                final isSelected = _userGuess == opt;
                return SizedBox(
                  width: 110,
                  height: 90,
                  child: ElevatedButton(
                    onPressed: _state == _TrenState.choosing
                        ? () => _onSelect(opt)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bg,
                      disabledBackgroundColor: bg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      '$opt',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: h * 0.055,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_state == _TrenState.finished) ...[
              SizedBox(height: h * 0.03),
              Text(
                _userGuess == _objetivo
                    ? '¡Correcto! Eran $_objetivo pasajeros'
                    : 'Eran $_objetivo pasajeros',
                style: TextStyle(
                  color: _userGuess == _objetivo
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  fontSize: h * 0.032,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Pintor de raíles ──
class _TrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final railPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final sleeperPaint = Paint()
      ..color = const Color(0xFF5D4037)
      ..strokeWidth = 5;

    final double rail1Y = size.height * 0.25;
    final double rail2Y = size.height * 0.75;

    // Traviesas
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, rail1Y - 8), Offset(x, rail2Y + 8), sleeperPaint);
      x += 48;
    }
    // Carriles
    canvas.drawLine(Offset(0, rail1Y), Offset(size.width, rail1Y), railPaint);
    canvas.drawLine(Offset(0, rail2Y), Offset(size.width, rail2Y), railPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
