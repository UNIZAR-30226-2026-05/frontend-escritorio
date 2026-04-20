import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../../core/widgets/retro_widgets.dart';
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
  late List<List<bool>> _wagonWindows;

  int _count = 0;
  int _adjustTime = 3;
  Timer? _adjustTimer;

  static const int _numWagons = 4;
  static const int _windowsPerWagon = 4;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _objetivo =
        (widget.details['objetivo'] as num?)?.toInt() ?? (4 + rng.nextInt(8));
    _wagonWindows = _distributePassengers(_objetivo, rng);

    _trainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _trainPos = Tween<double>(begin: -1.6, end: 1.6).animate(
      CurvedAnimation(parent: _trainCtrl, curve: Curves.linear),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
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
    const capacity = _numWagons * _windowsPerWagon;
    int remaining = total.clamp(0, capacity);
    final counts = List.filled(_numWagons, 0);
    for (int i = 0; i < _numWagons - 1 && remaining > 0; i++) {
      final maxVal = min(remaining, _windowsPerWagon);
      counts[i] = rng.nextInt(maxVal + 1);
      remaining -= counts[i];
    }
    counts[_numWagons - 1] = remaining;
    return counts.map((n) {
      final windows = List.generate(_windowsPerWagon, (i) => i < n);
      windows.shuffle(rng);
      return windows;
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
    return Positioned.fill(
      child: Image.asset(
        'assets/images/minigames/tren/vias.png',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildAnimatedTrain(double w, double h) {
    final wagonH = h * 0.38;
    final wagonW = wagonH * 2.2;
    final totalW = wagonW * _numWagons;

    return AnimatedBuilder(
      animation: _trainPos,
      builder: (_, __) {
        final left = _trainPos.value * w - totalW / 2;
        return Positioned(
          left: left,
          top: h * 0.30,
          child: SizedBox(
            width: totalW,
            height: wagonH,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                _numWagons,
                (i) => _buildWagon(wagonW, wagonH, _wagonWindows[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWagon(double w, double h, List<bool> windows) {
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/minigames/tren/vagon.png',
              fit: BoxFit.fill,
            ),
          ),
          ...List.generate(windows.length, (i) {
            if (!windows[i]) return const SizedBox.shrink();
            const slotWidth = 1.0 / (_windowsPerWagon + 1);
            final cx = slotWidth * (i + 1);
            final ballSize = h * 0.13;
            return Positioned(
              left: w * cx - ballSize / 2,
              top: h * 0.32,
              child: Container(
                width: ballSize,
                height: ballSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFCC02),
                  border: Border.all(color: Colors.black87, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 3)
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCounterBar(double h) {
    final canAct = _state != _TrenState.finished;
    final btnW = h * 0.075;
    final btnH = h * 0.075;
    final counterFontSize = h * 0.065;
    return Positioned(
      bottom: h * 0.05,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: h * 0.02, vertical: h * 0.008),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(h * 0.018),
            border: Border.all(
                color: const Color.fromARGB(255, 148, 148, 148).withValues(alpha: 0.75),
                width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RetroImgButton(
                label: '-',
                asset: 'assets/images/ui/btn_rojo.png',
                width: btnW,
                height: btnH,
                fontSize: btnH * 0.55,
                outlined: true,
                onTap: canAct
                    ? () => setState(() => _count = max(0, _count - 1))
                    : null,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: h * 0.07),
                child: Text(
                  '$_count',
                  style: TextStyle(
                    fontFamily: 'Retro Gaming',
                    color: const Color(0xFFFFCC02),
                    fontSize: counterFontSize,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(color: Color(0xFFFFCC02), blurRadius: 6),
                    ],
                  ),
                ),
              ),
              RetroImgButton(
                label: '+',
                asset: 'assets/images/ui/btn_verde.png',
                width: btnW,
                height: btnH,
                fontSize: btnH * 0.55,
                outlined: true,
                onTap: canAct ? () => setState(() => _count++) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
              fontFamily: 'Retro Gaming',
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
              fontFamily: 'Retro Gaming',
              color: _adjustTime <= 1 ? Colors.redAccent : Colors.white,
              fontSize: h * 0.030,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'pasajeros contados',
            style: TextStyle(
              fontFamily: 'Retro Gaming',
              color: Colors.white70,
              fontSize: h * 0.020,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarning(double h) {
    return Center(
      child: Text(
        '¡El tren está llegando!\nCuenta los pasajeros',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Retro Gaming',
          color: Colors.amber,
          fontSize: h * 0.038,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
    );
  }
}
