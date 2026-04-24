import 'dart:math';
import 'package:flutter/material.dart';
import 'minigame_base.dart';
import '../../../../../core/widgets/retro_widgets.dart';

enum GamePhase { preFlop, flop, turn, river }

class PokerCard {
  final String suit;
  final int rank;
  PokerCard(this.suit, this.rank);
}

class Rival {
  final int id;
  final String name;
  final String role;
  int balance;
  int currentBet;
  bool folded;
  final String position;
  List<PokerCard> cards;
  Rival({required this.id, required this.name, required this.role, required this.balance, this.currentBet = 0, this.folded = false, required this.position, required this.cards});
}

class PokerGame extends MinigameBase {
  const PokerGame({super.key, required super.onFinish, required super.details});
  @override
  State<PokerGame> createState() => _PokerGameState();
}

class _PokerGameState extends State<PokerGame> {
  bool _isDebug = true;
  bool _showCards = false;
  GamePhase _gamePhase = GamePhase.preFlop;
  final int _flopCardsCount = 3;
  int _currentTurnId = 0;
  int _winnerId = -1;
  List<PokerCard> _myCards = [];
  List<PokerCard> _communityCards = [];
  int _myCurrentBet = 0;
  int _myBalance = 10;
  int _pot = 0;
  double _raiseAmount = 10;
  List<Rival> _rivals = [];

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final suits = ['hearts', 'diamonds', 'spades', 'clubs'];
    final deck = <PokerCard>[];
    for (final s in suits) {
      for (int r = 1; r <= 13; r++) {
        deck.add(PokerCard(s, r));
      }
    }
    deck.shuffle(Random());
    _myCards = deck.sublist(0, 2);
    _communityCards = deck.sublist(2, 7);
    final roles = ['banquero', 'escapista', 'vidente'];
    final positions = ['left', 'top', 'right'];
    _rivals = List.generate(3, (i) => Rival(
      id: i + 1, name: roles[i][0].toUpperCase() + roles[i].substring(1),
      role: roles[i], balance: 10, currentBet: 0, folded: false,
      position: positions[i], cards: deck.sublist(7 + i * 2, 9 + i * 2),
    ));
    _myBalance = 10;
    _myCurrentBet = 0;
    _pot = 0;
    _gamePhase = GamePhase.preFlop;
    _winnerId = -1;
    _currentTurnId = 0;
    _raiseAmount = 10;
    _showCards = false;
    if (mounted) setState(() {});
  }

  int get _highestBet {
    int h = _myCurrentBet;
    for (final r in _rivals) { if (r.currentBet > h) h = r.currentBet; }
    return h;
  }

  int get _visibleCommunityCount {
    switch (_gamePhase) {
      case GamePhase.preFlop: return 0;
      case GamePhase.flop: return _flopCardsCount;
      case GamePhase.turn: return 4;
      case GamePhase.river: return 5;
    }
  }

  void _handleAction(String type) {
    setState(() {
      if (type == 'fold') {
        widget.onFinish(0);
        return;
      }
      if (type == 'call') {
        final callAmt = (_highestBet - _myCurrentBet).clamp(0, _myBalance);
        _myBalance -= callAmt;
        _pot += callAmt;
        _myCurrentBet += callAmt;
        _currentTurnId = 1;
      } else if (type == 'raise') {
        final commit = ((_highestBet - _myCurrentBet) + _raiseAmount.toInt()).clamp(0, _myBalance);
        _myBalance -= commit;
        _pot += commit;
        _myCurrentBet += commit;
        _currentTurnId = 1;
      }
    });
  }

  void _updateRivalAction(int id, String action) {
    setState(() {
      final r = _rivals.firstWhere((rv) => rv.id == id);
      if (action == 'fold') { r.folded = true; return; }
      if (action == 'call') {
        final amt = (_highestBet - r.currentBet).clamp(0, r.balance);
        r.balance -= amt;
        r.currentBet += amt;
        _pot += amt;
      } else if (action == 'raise') {
        const raiseVal = 20;
        final total = ((_highestBet - r.currentBet) + raiseVal).clamp(0, r.balance);
        r.balance -= total;
        r.currentBet += total;
        _pot += total;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // Background
        Image.asset('assets/images/minigames/cartas/fondo_cartas_videojugador.png', fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1B2A3B))),
        Container(color: Colors.black.withValues(alpha: 0.4)),

        // Center: Pot + Community Cards
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.8), border: Border.all(color: const Color(0xFFF59E0B), width: 2), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              const Text('BOTE TOTAL', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 10, color: Color(0xFFF59E0B), letterSpacing: 3)),
              const SizedBox(height: 4),
              Text('$_pot¢', style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 32, color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
            final visible = i < _visibleCommunityCount && i < _communityCards.length;
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Container(
              width: 72, height: 108,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
              child: ClipRRect(borderRadius: BorderRadius.circular(8), child: visible
                ? Image.asset('assets/images/minigames/cartas/cards/card_${_communityCards[i].suit}_${_communityCards[i].rank}.png', fit: BoxFit.contain, filterQuality: FilterQuality.none)
                : Image.asset('assets/images/minigames/cartas/carta_recortada.png', fit: BoxFit.contain, filterQuality: FilterQuality.none)),
            ));
          })),
        ])),

        // Rivals
        ..._rivals.map((r) => _buildRival(r, size)),

        // Local Player HUD (Bottom)
        Positioned(bottom: 0, left: 0, right: 0, child: Container(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.95), Colors.black.withValues(alpha: 0.6), Colors.transparent])),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // My Cards + Avatar
            Row(children: [
              ..._myCards.asMap().entries.map((e) => Transform.rotate(angle: e.key == 0 ? -0.2 : 0.2, child: Container(
                width: 96, height: 132, margin: EdgeInsets.only(right: e.key == 0 ? 0 : 0, left: e.key == 1 ? 0 : 0),
                child: ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/images/minigames/cartas/cards/card_${e.value.suit}_${e.value.rank}.png', fit: BoxFit.contain, filterQuality: FilterQuality.none))))),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                if (_currentTurnId == 0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(4)),
                  child: const Text('ES TU TURNO', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Colors.black, fontWeight: FontWeight.bold))),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _currentTurnId == 0 ? const Color(0xFFF59E0B) : Colors.white24, width: 3)),
                    child: ClipOval(child: Image.asset('assets/images/characters/general/videojugador_perfil.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white)))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('TÚ', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 9, color: Color(0xFFF59E0B), letterSpacing: 2)),
                    Text('$_myBalance¢', style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 28, color: Colors.white)),
                  ]),
                ]),
              ]),
            ]),
            const Spacer(),
            // Betting Actions
            if (_currentTurnId == 0 && _winnerId == -1) Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (_myCurrentBet > 0) Padding(padding: const EdgeInsets.only(right: 16), child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.3), border: Border.all(color: Colors.blue.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(4)),
                child: Column(children: [
                  const Text('APUESTA', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Colors.blue)),
                  Text('$_myCurrentBet¢', style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
              )),
              RetroImgButton(label: 'RETIRARSE', asset: 'assets/images/ui/btn_rojo.png', width: 160, height: 56, fontSize: 12, onTap: () => _handleAction('fold')),
              const SizedBox(width: 12),
              RetroImgButton(label: _highestBet > _myCurrentBet ? 'IGUALAR ${_highestBet - _myCurrentBet}¢' : 'PASAR',
                asset: 'assets/images/ui/btn_verde.png', width: 180, height: 56, fontSize: 11, onTap: () => _handleAction('call')),
              const SizedBox(width: 12),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), border: Border.all(color: Colors.purple.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(8)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('SUBIR ', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Colors.purple, letterSpacing: 2)),
                    Text('+${_raiseAmount.toInt()}¢', style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                  SizedBox(width: 140, child: SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: Colors.purple, thumbColor: Colors.purple, inactiveTrackColor: Colors.white12, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                    child: Slider(min: 1, max: (_myBalance - (_highestBet - _myCurrentBet)).clamp(1, 999).toDouble(), value: _raiseAmount.clamp(1, (_myBalance - (_highestBet - _myCurrentBet)).clamp(1, 999).toDouble()),
                      onChanged: (v) => setState(() => _raiseAmount = v)))),
                  RetroImgButton(label: 'SUBIR', asset: 'assets/images/ui/btn_morado.png', width: 140, height: 44, fontSize: 11, onTap: () => _handleAction('raise')),
                ]),
              ),
            ]),
          ]),
        )),

        // Debug Panel
        if (_isDebug) _buildDebugPanel(),

        // Winner Overlay
        if (_winnerId != -1) _buildWinnerOverlay(),
      ]),
    );
  }

  Widget _buildRival(Rival r, Size size) {
    final isTurn = _currentTurnId == r.id;
    double? left, right, top, bottom;
    if (r.position == 'left') { left = 40; top = size.height * 0.35; }
    else if (r.position == 'top') { left = size.width / 2 - 60; top = 40; }
    else { right = 40; top = size.height * 0.35; }

    return Positioned(left: left, right: right, top: top, bottom: bottom,
      child: AnimatedOpacity(duration: const Duration(milliseconds: 300), opacity: r.folded ? 0.3 : 1.0,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Cards
          Row(mainAxisSize: MainAxisSize.min, children: r.cards.asMap().entries.map((e) => Transform.rotate(
            angle: e.key == 0 ? -0.2 : 0.2,
            child: Container(width: 48, height: 68, margin: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(borderRadius: BorderRadius.circular(6),
                child: _showCards && !r.folded
                  ? Image.asset('assets/images/minigames/cartas/cards/card_${e.value.suit}_${e.value.rank}.png', fit: BoxFit.contain, filterQuality: FilterQuality.none)
                  : Image.asset('assets/images/minigames/cartas/carta_recortada.png', fit: BoxFit.contain, filterQuality: FilterQuality.none))),
          )).toList()),
          const SizedBox(height: 8),
          // Avatar
          Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            if (isTurn) Positioned.fill(child: Container(decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 8)]))),
            Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: isTurn ? Colors.blue : Colors.white24, width: 2)),
              child: ClipOval(child: Image.asset('assets/images/characters/general/${r.role}_perfil.png', fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white)))),
            if (r.folded) Positioned.fill(child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withValues(alpha: 0.7)),
              child: const Center(child: Text('X', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold))))),
            Positioned(bottom: -4, right: -4, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white24)),
              child: Text('${r.balance}¢', style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Colors.white)))),
          ]),
          const SizedBox(height: 6),
          if (isTurn) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
            child: const Text('SU TURNO', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 7, color: Colors.white))),
          Text(r.name, style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 10, color: isTurn ? Colors.blue : Colors.white70, letterSpacing: 2)),
          if (r.currentBet > 0 && !r.folded) Padding(padding: const EdgeInsets.only(top: 4),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.3))),
              child: Text('${r.currentBet}¢', style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 9, color: Colors.blue)))),
        ]),
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Positioned(top: 16, left: 16, child: Container(width: 280, padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.95), border: Border.all(color: Colors.purple, width: 2), borderRadius: BorderRadius.circular(8)),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('POKER DEBUGGER', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 9, color: Colors.purple)),
          GestureDetector(onTap: () => setState(() => _isDebug = false), child: const Text('✕', style: TextStyle(color: Colors.red, fontSize: 14))),
        ]),
        const SizedBox(height: 8),
        const Text('FASE', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Colors.white54)),
        const SizedBox(height: 4),
        Row(children: GamePhase.values.map((p) => Expanded(child: GestureDetector(
          onTap: () => setState(() => _gamePhase = p),
          child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: _gamePhase == p ? Colors.purple : Colors.white10, borderRadius: BorderRadius.circular(4)),
            child: Text(p.name, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 7, color: _gamePhase == p ? Colors.white : Colors.white54))),
        ))).toList()),
        const SizedBox(height: 8),
        Row(children: [
          const Text('Mi saldo: ', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Colors.white54)),
          Expanded(child: Slider(min: 0, max: 100, value: _myBalance.toDouble(), activeColor: Colors.purple, onChanged: (v) => setState(() => _myBalance = v.toInt()))),
          Text('$_myBalance', style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Colors.white)),
        ]),
        const SizedBox(height: 4),
        const Text('ACCIONES RIVALES', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Colors.purple)),
        ..._rivals.map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(width: 70, child: Text(r.name, style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 7, color: Colors.white))),
            _dbgBtn('F', Colors.red, () => _updateRivalAction(r.id, 'fold')),
            _dbgBtn('C', Colors.green, () => _updateRivalAction(r.id, 'call')),
            _dbgBtn('R', Colors.purple, () => _updateRivalAction(r.id, 'raise')),
          ]))),
        const SizedBox(height: 4),
        const Text('FORZAR GANADOR', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Color(0xFFF59E0B))),
        Row(children: [
          _dbgBtn('TÚ', const Color(0xFFF59E0B), () => setState(() => _winnerId = 0)),
          _dbgBtn('RIVAL', const Color(0xFFF59E0B), () => setState(() => _winnerId = Random().nextInt(3) + 1)),
        ]),
        const SizedBox(height: 4),
        GestureDetector(onTap: () => setState(() => _showCards = !_showCards),
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: _showCards ? const Color(0xFFF59E0B) : Colors.white10, borderRadius: BorderRadius.circular(4)),
            child: Text(_showCards ? 'ESCONDER CARTAS' : 'MOSTRAR CARTAS', textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: _showCards ? Colors.black : Colors.white)))),
        const SizedBox(height: 4),
        GestureDetector(onTap: () { _initGame(); setState(() {}); },
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
            child: const Text('REINICIAR MESA', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 8, color: Colors.white)))),
      ]))));
  }

  Widget _dbgBtn(String label, Color c, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 7, color: c))));
  }

  Widget _buildWinnerOverlay() {
    final isMe = _winnerId == 0;
    final winnerName = isMe ? 'TÚ' : _rivals.firstWhere((r) => r.id == _winnerId, orElse: () => _rivals.first).name;
    final winnerRole = isMe ? 'videojugador' : _rivals.firstWhere((r) => r.id == _winnerId, orElse: () => _rivals.first).role;
    return Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.85),
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF59E0B), width: 6),
          boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 8)]),
          child: ClipOval(child: Image.asset('assets/images/characters/general/${winnerRole}_perfil.png', fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.emoji_events, size: 80, color: Color(0xFFF59E0B))))),
        const SizedBox(height: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(4)),
          child: const Text('GANADOR', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 16, color: Colors.black, letterSpacing: 3))),
        const SizedBox(height: 16),
        Text(winnerName, style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 32, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('SE LLEVA EL BOTE', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 12, color: Color(0xFFF59E0B), letterSpacing: 2)),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            const Text('TOTAL PREMIO', style: TextStyle(fontFamily: 'Retro Gaming', fontSize: 9, color: Colors.white38)),
            Text('$_pot¢', style: const TextStyle(fontFamily: 'Retro Gaming', fontSize: 48, color: Color(0xFFF59E0B))),
          ])),
        const SizedBox(height: 32),
        RetroImgButton(label: 'NUEVA PARTIDA', asset: 'assets/images/ui/btn_verde.png', width: 220, height: 60, fontSize: 14, onTap: _initGame),
      ]))));
  }
}
