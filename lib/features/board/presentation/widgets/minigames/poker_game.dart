import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/widgets/retro_widgets.dart';
import '../../../data/websocket_service.dart';
import '../../controllers/game_provider.dart';
import '../../../../auth/presentation/controllers/auth_provider.dart';

enum GamePhase { preFlop, flop, turn, river }

class PokerCard {
  final String suit;
  final int rank;
  PokerCard(this.suit, this.rank);

  factory PokerCard.fromBackend(dynamic card) {
    if (card is Map) {
      final suitRaw =
          (card['suit'] ?? card['palo'] ?? '').toString().toLowerCase();
      final rankRaw =
          (card['rank'] ?? card['valor'] ?? '').toString().toLowerCase();

      String suit = 'spades'; // fallback
      if (suitRaw == 'corazones' || suitRaw == 'hearts') {
        suit = 'hearts';
      } else if (suitRaw == 'diamantes' || suitRaw == 'diamonds') {
        suit = 'diamonds';
      } else if (suitRaw == 'treboles' || suitRaw == 'clubs') {
        suit = 'clubs';
      } else if (suitRaw == 'picas' || suitRaw == 'spades') {
        suit = 'spades';
      }

      int rank = 1; // fallback (As)
      if (rankRaw == 'as' || rankRaw == '1' || rankRaw == '14') {
        rank = 1;
      } else if (rankRaw == 'jota' || rankRaw == 'j' || rankRaw == '11') {
        rank = 11;
      } else if (rankRaw == 'reina' || rankRaw == 'q' || rankRaw == '12') {
        rank = 12;
      } else if (rankRaw == 'rey' || rankRaw == 'k' || rankRaw == '13') {
        rank = 13;
      } else {
        rank = int.tryParse(rankRaw) ?? 1;
      }

      return PokerCard(suit, rank);
    }
    // Si viene como entero (0-51)
    final suits = ['hearts', 'diamonds', 'spades', 'clubs'];
    final s = suits[card ~/ 13];
    final r = (card % 13) + 1;
    return PokerCard(s, r);
  }
}

class Rival {
  final String id;
  final String name;
  final String role;
  int balance;
  int currentBet;
  bool folded;
  final String position;
  List<PokerCard> cards;

  Rival({
    required this.id,
    required this.name,
    required this.role,
    required this.balance,
    this.currentBet = 0,
    this.folded = false,
    required this.position,
    this.cards = const [],
  });
}

class PokerGame extends ConsumerStatefulWidget {
  final Function(dynamic score) onFinish;
  final Map<String, dynamic> details;

  const PokerGame({super.key, required this.onFinish, required this.details});

  @override
  ConsumerState<PokerGame> createState() => _PokerGameState();
}

class _PokerGameState extends ConsumerState<PokerGame> {
  bool _showCards = false;
  String _currentPhase = 'preFlop';
  bool _hasActedThisPhase = false;
  bool _gameFinished = false;
  String _resultMessage = '';
  List<PokerCard> _myCards = [];
  List<PokerCard> _communityCards = [];
  int _myCurrentBet = 0;
  int _myBalance = 0;
  int _pot = 0;
  double _raiseAmount = 1;
  List<Rival> _rivals = [];

  @override
  void initState() {
    super.initState();
    // Leer los detalles más recientes del provider por si ya llegaron antes del mount
    final currentDetails = ref.read(gameProvider).minigameDetails;
    _parseBackendDetails(currentDetails ?? widget.details);
  }

  void _parseBackendDetails(Map<String, dynamic> details) {
    final type = details['type'] as String? ?? '';
    debugPrint(
        "DEBUG POKER: Procesando detalles. Fase actual: ${details['fase']}, Tipo: $type");
    setState(() {
      // Bote
      if (details.containsKey('bote')) {
        _pot = details['bote'];
      } else if (details.containsKey('poker_bote')) {
        _pot = details['poker_bote'];
      } else if (details.containsKey('bote_actual')) {
        _pot = details['bote_actual'];
      }

      // Fase: cuando llega una nueva fase, reseteamos el flag de "ya he actuado"
      if (details.containsKey('fase')) {
        final newPhase = details['fase'] as String;
        if (newPhase != _currentPhase) {
          _currentPhase = newPhase;
          _hasActedThisPhase = false;
          _raiseAmount = 1; // resetear slider
        }
      }

      // poker_inicio_ronda = nueva mano, resetear todo
      if (type == 'poker_inicio_ronda') {
        _gameFinished = false;
        _hasActedThisPhase = false;
        _resultMessage = '';
        _communityCards = [];
        _myCurrentBet = 0;
      }

      // backend_error = el backend rechazó nuestra acción (ej. saldo insuficiente)
      // Reseteamos el flag para que el jugador pueda reintentar
      if (type == 'backend_error') {
        debugPrint(
            ' [POKER] Error del backend: ${details['error']}. Reactivando botones.');
        _hasActedThisPhase = false;
      }

      // poker_resultados o poker_victoria_abandono = fin de la mano
      if (type == 'poker_resultados' || type == 'poker_victoria_abandono') {
        _gameFinished = true;
        _showCards = true;
        if (details.containsKey('mensaje')) {
          _resultMessage = details['mensaje'];
        } else if (details.containsKey('ganador')) {
          _resultMessage =
              '${details['ganador']} gana ${details['bote_ganado'] ?? 0}¢';
        }
        // Mostrar cartas de rivales si están en los resultados
        if (details.containsKey('resultados_ordenados')) {
          final resultados = details['resultados_ordenados'] as List;
          for (final r in resultados) {
            final rivalMatch = _rivals
                .where((rv) =>
                    rv.id == r['usuario_id'] || rv.name == r['usuario_id'])
                .firstOrNull;
            if (rivalMatch != null && r.containsKey('cartas')) {
              rivalMatch.cards = (r['cartas'] as List)
                  .map((c) => PokerCard.fromBackend(c))
                  .toList();
            }
          }
        }
        if (details.containsKey('mesa_completa')) {
          _communityCards = (details['mesa_completa'] as List)
              .map((c) => PokerCard.fromBackend(c))
              .toList();
        }
      }

      // Cartas propias
      if (details.containsKey('cartas_propias')) {
        _myCards = (details['cartas_propias'] as List)
            .map((c) => PokerCard.fromBackend(c))
            .toList();
      } else if (details.containsKey('mis_cartas')) {
        _myCards = (details['mis_cartas'] as List)
            .map((c) => PokerCard.fromBackend(c))
            .toList();
      }

      // Cartas comunitarias (solo si no es resultado final, para no sobreescribir mesa_completa)
      if (type != 'poker_resultados') {
        if (details.containsKey('comunitarias')) {
          _communityCards = (details['comunitarias'] as List)
              .map((c) => PokerCard.fromBackend(c))
              .toList();
        } else if (details.containsKey('poker_flop')) {
          _communityCards = (details['poker_flop'] as List)
              .map((c) => PokerCard.fromBackend(c))
              .toList();
        } else if (details.containsKey('mesa_visible')) {
          _communityCards = (details['mesa_visible'] as List)
              .map((c) => PokerCard.fromBackend(c))
              .toList();
        }
      }

      // Jugadores y balances
      final gameState = ref.read(gameProvider);
      final myUsername = ref.read(authProvider).username ?? '';

      final myPlayer =
          gameState.players.where((p) => p.username == myUsername).firstOrNull;
      _myBalance = myPlayer?.coins ?? 0;

      // Reconstruir rivales (excluyendo al local)
      _rivals = gameState.players
          .where((p) => p.username != myUsername)
          .toList()
          .asMap()
          .entries
          .map((e) {
        final p = e.value;
        final pos = ['left', 'top', 'right'][e.key % 3];
        return Rival(
          id: p.id,
          name: p.username,
          role: p.characterClass.name,
          balance: p.coins,
          position: pos,
        );
      }).toList();

      // Actualizar estados de apuestas desde detalles si existen
      if (details.containsKey('apuestas')) {
        final apuestas = details['apuestas'] as Map<String, dynamic>;
        apuestas.forEach((user, bet) {
          if (user == myUsername) {
            _myCurrentBet = bet;
          } else {
            final rival = _rivals.where((r) => r.name == user).firstOrNull;
            if (rival != null) rival.currentBet = bet;
          }
        });
      }

      if (details.containsKey('retirados')) {
        final retirados = List<String>.from(details['retirados']);
        for (var user in retirados) {
          final rival = _rivals.where((r) => r.name == user).firstOrNull;
          if (rival != null) rival.folded = true;
        }
      }
    });
    debugPrint(
        "DEBUG POKER: Estado final del widget - Fase: $_currentPhase, Actuado: $_hasActedThisPhase");
  }

  int get _highestBet {
    int h = _myCurrentBet;
    for (final r in _rivals) {
      if (r.currentBet > h) h = r.currentBet;
    }
    return h;
  }

  void _handleAction(String type) {
    int amount = 0;
    String decision = 'apostar'; // Por defecto para call y raise

    if (type == 'fold') {
      decision = 'retirarse';
    } else if (type == 'call') {
      decision = 'apostar';
      amount = (_highestBet - _myCurrentBet).clamp(0, _myBalance);
    } else if (type == 'raise') {
      decision = 'apostar';
      amount = ((_highestBet - _myCurrentBet) + _raiseAmount.toInt())
          .clamp(0, _myBalance);
    }

    debugPrint(
        ' [POKER] Acción enviada: $decision ($amount) [balance: $_myBalance]');
    ref.read(webSocketProvider).sendPokerAction(decision, amount);
    setState(() {
      _hasActedThisPhase = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar actualizaciones del backend que llegan via details
    ref.listen<Map<String, dynamic>?>(
        gameProvider.select((s) => s.minigameDetails), (prev, next) {
      if (next != null) {
        _parseBackendDetails(next);
      }
    });

    ref.watch(authProvider).username;
    // El backend usa fases simultáneas: todos actúan a la vez.
    // Mostramos botones si hay fase activa, no hemos actuado aún, y la partida no ha terminado.
    final canAct =
        _currentPhase.isNotEmpty && !_hasActedThisPhase && !_gameFinished;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // Background
        Image.asset(
            'assets/images/minigames/cartas/fondo_cartas_videojugador.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Container(color: const Color(0xFF1B2A3B))),
        Container(color: Colors.black.withValues(alpha: 0.4)),

        // Center: Pot + Community Cards
        Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              const Text('BOTE TOTAL',
                  style: TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: 10,
                      color: Color(0xFFF59E0B),
                      letterSpacing: 3)),
              const SizedBox(height: 4),
              Text('$_pot¢',
                  style: const TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: 32,
                      color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 24),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final visible = i < _communityCards.length;
                return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 72,
                      height: 108,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1))),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: visible
                              ? Image.asset(
                                  'assets/images/minigames/cartas/cards/card_${_communityCards[i].suit}_${_communityCards[i].rank}.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none)
                              : Image.asset(
                                  'assets/images/minigames/cartas/carta_recortada.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none)),
                    ));
              })),
        ])),

        // Rivals
        ..._rivals.map((r) => _buildRival(r, size)),

        // Local Player HUD (Bottom)
        Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent
                  ])),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                // My Cards + Avatar
                Row(children: [
                  ..._myCards.asMap().entries.map((e) => Transform.rotate(
                      angle: e.key == 0 ? -0.2 : 0.2,
                      child: Container(
                          width: 96,
                          height: 132,
                          margin: EdgeInsets.only(
                              right: e.key == 0 ? 0 : 0,
                              left: e.key == 1 ? 0 : 0),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                  'assets/images/minigames/cartas/cards/card_${e.value.suit}_${e.value.rank}.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none))))),
                  const SizedBox(width: 16),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canAct)
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                  'FASE: ${_currentPhase.toUpperCase()}',
                                  style: const TextStyle(
                                      fontFamily: 'Retro Gaming',
                                      fontSize: 8,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold))),
                        if (_hasActedThisPhase && !_gameFinished)
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('ESPERANDO...',
                                  style: TextStyle(
                                      fontFamily: 'Retro Gaming',
                                      fontSize: 8,
                                      color: Colors.white70))),
                        if (_gameFinished && _resultMessage.isNotEmpty)
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFFF59E0B))),
                              child: Text(_resultMessage,
                                  style: const TextStyle(
                                      fontFamily: 'Retro Gaming',
                                      fontSize: 8,
                                      color: Color(0xFFF59E0B)))),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: canAct
                                          ? const Color(0xFFF59E0B)
                                          : Colors.white24,
                                      width: 3)),
                              child: ClipOval(
                                  child: Image.asset(
                                      'assets/images/characters/general/videojugador_perfil.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.person,
                                          color: Colors.white)))),
                          const SizedBox(width: 12),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('TÚ',
                                    style: TextStyle(
                                        fontFamily: 'Retro Gaming',
                                        fontSize: 9,
                                        color: Color(0xFFF59E0B),
                                        letterSpacing: 2)),
                                Text('$_myBalance¢',
                                    style: const TextStyle(
                                        fontFamily: 'Retro Gaming',
                                        fontSize: 28,
                                        color: Colors.white)),
                              ]),
                        ]),
                      ]),
                ]),
                const Spacer(),
                // Betting Actions
                if (canAct)
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    if (_myCurrentBet > 0)
                      Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.3),
                                border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(4)),
                            child: Column(children: [
                              const Text('TU APUESTA',
                                  style: TextStyle(
                                      fontFamily: 'Retro Gaming',
                                      fontSize: 8,
                                      color: Colors.blue)),
                              Text('$_myCurrentBet¢',
                                  style: const TextStyle(
                                      fontFamily: 'Retro Gaming',
                                      fontSize: 18,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          )),
                    RetroImgButton(
                        label: 'RETIRARSE',
                        asset: 'assets/images/ui/btn_rojo.png',
                        width: 160,
                        height: 56,
                        fontSize: 12,
                        onTap: () => _handleAction('fold')),
                    const SizedBox(width: 12),
                    RetroImgButton(
                        label: _highestBet > _myCurrentBet
                            ? 'IGUALAR ${_highestBet - _myCurrentBet}¢'
                            : 'PASAR',
                        asset: 'assets/images/ui/btn_verde.png',
                        width: 180,
                        height: 56,
                        fontSize: 11,
                        onTap: () => _handleAction('call')),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          border: Border.all(
                              color: Colors.purple.withValues(alpha: 0.3)),
                          borderRadius: BorderRadius.circular(8)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('SUBIR ',
                              style: TextStyle(
                                  fontFamily: 'Retro Gaming',
                                  fontSize: 8,
                                  color: Colors.purple,
                                  letterSpacing: 2)),
                          Text('+${_raiseAmount.toInt()}¢',
                              style: const TextStyle(
                                  fontFamily: 'Retro Gaming',
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        SizedBox(
                            width: 140,
                            child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.purple,
                                    thumbColor: Colors.purple,
                                    inactiveTrackColor: Colors.white12,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 8)),
                                child: Slider(
                                    min: 1,
                                    max: (_myBalance -
                                            (_highestBet - _myCurrentBet))
                                        .clamp(1, 999)
                                        .toDouble(),
                                    value: _raiseAmount.clamp(
                                        1,
                                        (_myBalance -
                                                (_highestBet - _myCurrentBet))
                                            .clamp(1, 999)
                                            .toDouble()),
                                    onChanged: (v) =>
                                        setState(() => _raiseAmount = v)))),
                        RetroImgButton(
                            label: 'SUBIR',
                            asset: 'assets/images/ui/btn_morado.png',
                            width: 140,
                            height: 44,
                            fontSize: 11,
                            onTap: () => _handleAction('raise')),
                      ]),
                    ),
                  ]),
              ]),
            )),

        // Botón para volver al tablero cuando la mano ha terminado
        if (_gameFinished)
          Positioned(
              top: 24,
              right: 24,
              child: RetroImgButton(
                  label: 'VOLVER',
                  asset: 'assets/images/ui/btn_verde.png',
                  width: 140,
                  height: 48,
                  fontSize: 11,
                  onTap: () => widget.onFinish(0))),

        // Debug Panel (Deshabilitado en producción)
      ]),
    );
  }

  Widget _buildRival(Rival r, Size size) {
    double? left, right, top, bottom;
    if (r.position == 'left') {
      left = 40;
      top = size.height * 0.35;
    } else if (r.position == 'top') {
      left = size.width / 2 - 60;
      top = 40;
    } else {
      right = 40;
      top = size.height * 0.35;
    }

    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: r.folded ? 0.3 : 1.0,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Cards (Dorso o reales si se desea mostrar al final)
          Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                  2,
                  (i) => Transform.rotate(
                        angle: i == 0 ? -0.2 : 0.2,
                        child: Container(
                            width: 48,
                            height: 68,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: _showCards &&
                                        !r.folded &&
                                        r.cards.isNotEmpty
                                    ? Image.asset(
                                        'assets/images/minigames/cartas/cards/card_${r.cards[i].suit}_${r.cards[i].rank}.png',
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.none)
                                    : Image.asset(
                                        'assets/images/minigames/cartas/carta_recortada.png',
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.none))),
                      )).toList()),
          const SizedBox(height: 8),
          // Avatar
          Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2)),
                    child: ClipOval(
                        child: Image.asset(
                            'assets/images/characters/general/${r.role}_perfil.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                color: Colors.white)))),
                if (r.folded)
                  Positioned.fill(
                      child: Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.red.withValues(alpha: 0.7)),
                          child: const Center(
                              child: Text('X',
                                  style: TextStyle(
                                      fontFamily: 'Retro Gaming',
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold))))),
                Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white24)),
                        child: Text('${r.balance}¢',
                            style: const TextStyle(
                                fontFamily: 'Retro Gaming',
                                fontSize: 8,
                                color: Colors.white)))),
              ]),
          const SizedBox(height: 6),
          Text(r.name,
              style: const TextStyle(
                  fontFamily: 'Retro Gaming',
                  fontSize: 10,
                  color: Colors.white70,
                  letterSpacing: 2)),
          if (r.currentBet > 0 && !r.folded)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3))),
                    child: Text('${r.currentBet}¢',
                        style: const TextStyle(
                            fontFamily: 'Retro Gaming',
                            fontSize: 9,
                            color: Colors.blue)))),
        ]),
      ),
    );
  }
}
