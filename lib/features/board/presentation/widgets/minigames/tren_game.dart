import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'minigame_base.dart';

enum _TrenState { waiting, passing, adjusting, finished }

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
  late Animation<double> _trainPos;

  late int _objetivo;
  late List<List<bool>> _wagonSeats;

  int _count = 0; // pasajeros contados por el usuario
  int _adjustTime = 3; // segundos restantes en fase adjusting
  Timer? _adjustTimer;

  static const int _numWagons = 3;
  static const int _seatsPerWagon = 8;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _objetivo = widget.details['objetivo'] as int? ?? 10;
    _wagonSeats = _distributePassengers(_objetivo, rng);

    _trainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
    _trainPos = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _trainCtrl, curve: Curves.linear),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _state = _TrenState.passing);
      _trainCtrl.forward();
    });

    _trainCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _state = _TrenState.adjusting;
          _adjustTime = 3;
        });
        _startAdjustTimer();
      }
    });
  }

  @override
  void dispose() {
    _trainCtrl.dispose();
    _adjustTimer?.cancel();
    super.dispose();
  }

  List<List<bool>> _distributePassengers(int total, Random rng) {
    final counts = List.filled(_numWagons, 0);
    int remaining = total.clamp(0, _seatsPerWagon * _numWagons);
    for (int i = 0; i < _numWagons - 1 && remaining > 0; i++) {
      final maxVal = min(remaining, _seatsPerWagon);
      counts[i] = rng.nextInt(maxVal + 1);
      remaining -= counts[i];
    }
    counts[_numWagons - 1] = remaining;
    return counts.map((n) {
      final seats = List.generate(_seatsPerWagon, (i) => i < n);
      seats.shuffle(rng);
      return seats;
    }).toList();
  }

  void _startAdjustTimer() {
    _adjustTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_adjustTime <= 1) {
        t.cancel();
        setState(() => _state = _TrenState.finished);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) widget.onFinish(_count);
        });
      } else {
        setState(() => _adjustTime--);
      }
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
            _buildBackground(),
            _buildTracks(w, h),
            if (_state == _TrenState.passing || _state == _TrenState.waiting)
              _buildAnimatedTrain(w, h),
            if (_state == _TrenState.waiting) _buildWarning(h),
            if (_state != _TrenState.finished) _buildCounterBar(h),
            if (_state == _TrenState.adjusting) _buildAdjustOverlay(h),
          ],
        );
      },
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.60, 0.60, 1.0],
          colors: [
            Color(0xFF0D1B2A),
            Color(0xFF1B2A3B),
            Color(0xFF3B5E3A),
            Color(0xFF2E4A2E),
          ],
        ),
      ),
    );
  }

  Widget _buildTracks(double w, double h) {
    return Positioned(
      left: 0,
      right: 0,
      top: h * 0.58,
      height: h * 0.12,
      child: CustomPaint(painter: _TrackPainter()),
    );
  }

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
              ...List.generate(_numWagons,
                  (i) => _buildWagon(wagonW, wagonH, _wagonSeats[i])),
            ],
          ),
        );
      },
    );
  }

  // ── Barra de contador siempre visible (bottom) ──
  Widget _buildCounterBar(double h) {
    final canAct = _state != _TrenState.finished;
    final btnSize = h * 0.09;
    return Positioned(
      bottom: h * 0.05,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAdjustButton(
            icon: Icons.remove,
            enabled: canAct,
            onTap: () => setState(() => _count = max(0, _count - 1)),
            size: btnSize,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              '$_count',
              style: TextStyle(
                color: Colors.white,
                fontSize: h * 0.13,
                fontWeight: FontWeight.bold,
                shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
          ),
          _buildAdjustButton(
            icon: Icons.add,
            enabled: canAct,
            onTap: () => setState(() => _count++),
            size: btnSize,
          ),
        ],
      ),
    );
  }

  // ── Overlay de cuenta atrás en fase adjusting ──
  Widget _buildAdjustOverlay(double h) {
    return Positioned(
      top: h * 0.04,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AJUSTA TU RESPUESTA',
            style: TextStyle(
              color: Colors.amber,
              fontSize: h * 0.036,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$_adjustTime s',
            style: TextStyle(
              color: _adjustTime <= 1 ? Colors.redAccent : Colors.white60,
              fontSize: h * 0.030,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'pasajeros contados',
            style: TextStyle(
              color: Colors.white38,
              fontSize: h * 0.020,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFF1565C0) : Colors.grey.shade800,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? const [
                  BoxShadow(
                      color: Colors.black45,
                      blurRadius: 6,
                      offset: Offset(0, 3))
                ]
              : null,
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.grey,
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildWarning(double h) {
    return Center(
      child: Text(
        '¡El tren está llegando!\nPulsa cada vez que veas un pasajero',
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
          Positioned(
            left: w * 0.18,
            top: -h * 0.18,
            child: Container(
              width: w * 0.14,
              height: h * 0.22,
              decoration: const BoxDecoration(
                color: Color(0xFF424242),
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
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
          Padding(
            padding:
                EdgeInsets.fromLTRB(w * 0.06, h * 0.08, w * 0.06, h * 0.22),
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
                    border: Border.all(color: Colors.black45, width: 0.5),
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
          Positioned(
            bottom: h * 0.08,
            left: 0,
            right: 0,
            child: Container(height: h * 0.06, color: const Color(0xFF0D47A1)),
          ),
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
      children: [_buildWheel(wheelSize), _buildWheel(wheelSize)],
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
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
        ),
      ),
    );
  }
}

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

    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
          Offset(x, rail1Y - 8), Offset(x, rail2Y + 8), sleeperPaint);
      x += 48;
    }
    canvas.drawLine(Offset(0, rail1Y), Offset(size.width, rail1Y), railPaint);
    canvas.drawLine(Offset(0, rail2Y), Offset(size.width, rail2Y), railPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
