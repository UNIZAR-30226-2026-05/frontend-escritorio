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

  //late int _objetivo;
  late List<int> _wagonCapacities;

  int _count = 0;
  int _adjustTime = 3;
  Timer? _adjustTimer;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // final rng = Random();
    // _objetivo = (widget.details['objetivo'] as num?)?.toInt() ?? (4 + rng.nextInt(8));
        
    if (widget.details['vagones'] != null) {
      _wagonCapacities = (widget.details['vagones'] as List)
          .map((e) => (e as num).toInt())
          .toList();
    } else {
      _wagonCapacities = [13, 11, 14, 8];
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final size = MediaQuery.of(context).size;
      final w = size.width;
      final h = size.height;

      final wagonH = h * 0.38;
      final wagonW = wagonH * 2.2;
      final totalW = wagonW * _wagonCapacities.length;

      // Distance a single wagon travels while visible is (w + wagonW).
      // Speed = (w + wagonW) / 8 pixels per second.
      // Total distance for the train is (w + totalW).
      // Total duration = distance / speed
      final durationSecs = 8.0 * (w + totalW) / (w + wagonW);

      _trainCtrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (durationSecs * 1000).toInt()),
      );

      _trainPos = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _trainCtrl, curve: Curves.linear),
      );

      _trainCtrl.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _state = _TrenState.adjusting;
            _adjustTime = 3;
          });
          _startAdjustTimer();
        }
      });

      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() => _state = _TrenState.passing);
        _trainCtrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _trainCtrl.dispose();
    _adjustTimer?.cancel();
    super.dispose();
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
    final totalW = wagonW * _wagonCapacities.length;
    
    // Animación de izquierda a derecha
    final startLeft = -totalW;
    final endLeft = w;

    return AnimatedBuilder(
      animation: _trainPos,
      builder: (_, __) {
        final left = startLeft + (endLeft - startLeft) * _trainPos.value;
        return Positioned(
          left: left,
          top: h * 0.30,
          child: SizedBox(
            width: totalW,
            height: wagonH,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                _wagonCapacities.length,
                (i) => _buildWagon(wagonW, wagonH, _wagonCapacities[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWagon(double w, double h, int capacity) {
    String imageAsset;
    switch (capacity) {
      case 13: imageAsset = 'vagon1_13pj.png'; break;
      case 11: imageAsset = 'vagon2_11pj.png'; break;
      case 6:  imageAsset = 'vagon3_6pj.png'; break;
      case 16: imageAsset = 'vagon4_16pj.png'; break;
      case 14: imageAsset = 'vagon5_14pj.png'; break;
      case 8:  imageAsset = 'vagon6_8pj.png'; break;
      default: imageAsset = 'vagon.png'; break; // Fallback
    }

    return SizedBox(
      width: w,
      height: h,
      child: Image.asset(
        'assets/images/minigames/tren/$imageAsset',
        fit: BoxFit.fill,
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
