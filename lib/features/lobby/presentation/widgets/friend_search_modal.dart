import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/retro_widgets.dart';
import '../../data/lobby_service.dart';
import '../../data/session_websocket_service.dart';
import '../controllers/lobby_provider.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';

class FriendSearchModal extends ConsumerStatefulWidget {
  const FriendSearchModal({super.key});

  @override
  ConsumerState<FriendSearchModal> createState() => _FriendSearchModalState();
}

class _FriendSearchModalState extends ConsumerState<FriendSearchModal> {
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  final LobbyService _service = LobbyService();

  List<String>? _results; // null = aún no se ha buscado
  bool _isLoading = false;
  String? _searchError;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _queryCtrl.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 3) {
      setState(() {
        _results = null;
        _isLoading = false;
        _searchError = null;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _searchError = null;
    });
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _doSearch(q),
    );
  }

  Future<void> _doSearch(String query) async {
    try {
      final results = await _service.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _isLoading = false;
        _searchError = 'Error al buscar usuarios';
      });
    }
  }

  void _sendRequest(String playerId) {
    ref.read(sessionWebSocketProvider).sendFriendRequest(playerId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Solicitud enviada a $playerId'),
        duration: const Duration(seconds: 2),
      ),
    );
    // Forzamos rebuild para que el chip cambie a "Pendiente" inmediatamente.
    setState(() {});
  }

  _SearchRowStatus _resolveStatus(
    String username, {
    required Set<String> allFriends,
    required Set<String> sentRequests,
  }) {
    if (allFriends.contains(username)) return _SearchRowStatus.amigo;
    if (sentRequests.contains(username)) return _SearchRowStatus.pendiente;
    return _SearchRowStatus.anyadir;
  }

  @override
  Widget build(BuildContext context) {
    final allFriends = ref.watch(lobbyProvider.select((s) => s.allFriends));
    final sentRequests =
        ref.watch(lobbyProvider.select((s) => s.sentFriendRequests));
    final currentUser = ref.read(authProvider).username ?? '';

    // Filtra el usuario actual de los resultados.
    final visibleResults = _results
        ?.where((u) => u != currentUser)
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 420,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B4E),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              offset: Offset(4, 4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'BUSCAR JUGADORES',
                    style: TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: 20,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.white, blurRadius: 12),
                        Shadow(color: Colors.white70, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Barra de búsqueda
            Container(
              height: 44,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/ui/rellenable.png'),
                  fit: BoxFit.fill,
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _queryCtrl,
                    focusNode: _queryFocus,
                    onChanged: _onQueryChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      final q = value.trim();
                      if (q.length >= 3) _doSearch(q);
                    },
                    style: const TextStyle(
                      fontFamily: 'Retro Gaming',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    cursorColor: const Color(0xFF6B21A8),
                    decoration: const InputDecoration(
                      hintText: 'Nombre de usuario',
                      hintStyle: TextStyle(
                        fontFamily: 'Retro Gaming',
                        fontSize: 13,
                        color: Colors.white54,
                      ),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Resultados
            SizedBox(
              height: 320,
              child: _buildBody(
                visibleResults: visibleResults,
                allFriends: allFriends,
                sentRequests: sentRequests,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required List<String>? visibleResults,
    required Set<String> allFriends,
    required Set<String> sentRequests,
  }) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Text(
          _searchError!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 12,
            color: Colors.redAccent,
          ),
        ),
      );
    }

    // Estado inicial: sin búsqueda.
    if (visibleResults == null) {
      return const Center(
        child: Text(
          'Escribe al menos 4 caracteres\npara buscar jugadores',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 12,
            color: Colors.white54,
            height: 1.5,
          ),
        ),
      );
    }

    if (visibleResults.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron jugadores',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: visibleResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final username = visibleResults[i];
        final status = _resolveStatus(
          username,
          allFriends: allFriends,
          sentRequests: sentRequests,
        );
        return _SearchRow(
          username: username,
          status: status,
          onAnyadir: status == _SearchRowStatus.anyadir
              ? () => _sendRequest(username)
              : null,
        );
      },
    );
  }
}

enum _SearchRowStatus { anyadir, pendiente, amigo }

class _SearchRow extends StatelessWidget {
  final String username;
  final _SearchRowStatus status;
  final VoidCallback? onAnyadir;

  const _SearchRow({
    required this.username,
    required this.status,
    required this.onAnyadir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1235),
        border: Border.all(color: Colors.white24, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              username,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 13,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.white, blurRadius: 10),
                  Shadow(color: Colors.white70, blurRadius: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildChip(),
        ],
      ),
    );
  }

  Widget _buildChip() {
    switch (status) {
      case _SearchRowStatus.anyadir:
        return RetroImgButton(
          label: 'Añadir',
          asset: 'assets/images/ui/btn_verde.png',
          width: 90,
          height: 30,
          fontSize: 11,
          onTap: onAnyadir,
        );
      case _SearchRowStatus.pendiente:
        return const RetroImgButton(
          label: 'Pendiente',
          asset: 'assets/images/ui/btn_morado.png',
          width: 90,
          height: 30,
          fontSize: 11,
          onTap: null,
        );
      case _SearchRowStatus.amigo:
        return const RetroImgButton(
          label: 'Amigo',
          asset: 'assets/images/ui/btn_verde.png',
          width: 90,
          height: 30,
          fontSize: 11,
          onTap: null,
        );
    }
  }
}
