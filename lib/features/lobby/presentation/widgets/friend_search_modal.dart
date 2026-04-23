import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/retro_widgets.dart';
import '../../data/session_websocket_service.dart';
import '../controllers/lobby_provider.dart';

// Modal "BUSCAR JUGADORES" para localizar usuarios y mandarles solicitud de
// amistad. Usa el WS de sesión (send_request) para crear la petición y se
// apoya en el estado del lobby para saber qué usuarios ya son amigos y a
// quiénes tenemos una solicitud pendiente (para pintar "Pendiente").
//
// El WS documentado no expone un endpoint para buscar usuarios por nombre,
// así que el modal trabaja con los usernames que ya conocemos (amigos online
// + solicitudes enviadas) y con el texto que teclea el usuario, que se añade
// como candidato "Añadir" si no encaja con ninguno de los anteriores.
class FriendSearchModal extends ConsumerStatefulWidget {
  const FriendSearchModal({super.key});

  @override
  ConsumerState<FriendSearchModal> createState() => _FriendSearchModalState();
}

class _FriendSearchModalState extends ConsumerState<FriendSearchModal> {
  final TextEditingController _queryCtrl = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  @override
  void dispose() {
    _queryCtrl.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _sendRequest(String playerId) {
    ref.read(sessionWebSocketProvider).sendFriendRequest(playerId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Solicitud enviada a $playerId'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Construye la lista de filas a mostrar según el query actual.
  // Orden: candidato "Añadir" (el query si no coincide con amigos/pendientes),
  // después pendientes, después amigos online (como "Amigo" deshabilitado).
  List<_FriendSearchEntry> _buildEntries({
    required String query,
    required Set<String> onlineFriends,
    required Set<String> sentFriendRequests,
  }) {
    final q = query.trim();
    final qLower = q.toLowerCase();

    // Candidato directo: solo si hay texto y no coincide con un amigo o pendiente.
    final bool isNewCandidate = q.isNotEmpty &&
        !onlineFriends.any((u) => u.toLowerCase() == qLower) &&
        !sentFriendRequests.any((u) => u.toLowerCase() == qLower);

    final entries = <_FriendSearchEntry>[];
    if (isNewCandidate) {
      entries.add(_FriendSearchEntry(
        username: q,
        status: _SearchRowStatus.anyadir,
      ));
    }

    // Pendientes que casan con el query (o todos si el query está vacío).
    final pendingMatches = sentFriendRequests
        .where((u) => qLower.isEmpty || u.toLowerCase().contains(qLower))
        .toList()
      ..sort();
    for (final u in pendingMatches) {
      entries.add(_FriendSearchEntry(
        username: u,
        status: _SearchRowStatus.pendiente,
      ));
    }

    // Amigos online que casan con el query.
    final friendMatches = onlineFriends
        .where((u) => qLower.isEmpty || u.toLowerCase().contains(qLower))
        .toList()
      ..sort();
    for (final u in friendMatches) {
      entries.add(_FriendSearchEntry(
        username: u,
        status: _SearchRowStatus.amigo,
      ));
    }

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final onlineFriends =
        ref.watch(lobbyProvider.select((s) => s.onlineFriends));
    final sentFriendRequests =
        ref.watch(lobbyProvider.select((s) => s.sentFriendRequests));

    final entries = _buildEntries(
      query: _queryCtrl.text,
      onlineFriends: onlineFriends,
      sentFriendRequests: sentFriendRequests,
    );

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
            // Cabecera: título a la izquierda + X a la derecha.
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

            // Barra de búsqueda: input con fondo "rellenable" + botón verde con lupa.
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/ui/rellenable.png'),
                        fit: BoxFit.fill,
                      ),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _queryCtrl,
                      focusNode: _queryFocus,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (value) {
                        final target = value.trim();
                        if (target.isEmpty) return;
                        _sendRequest(target);
                        _queryCtrl.clear();
                        setState(() {});
                      },
                      style: const TextStyle(
                        fontFamily: 'Retro Gaming',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                      cursorColor: const Color(0xFF6B21A8),
                      decoration: const InputDecoration(
                        hintText: 'Nombre del jugador...',
                        hintStyle: TextStyle(
                          fontFamily: 'Retro Gaming',
                          fontSize: 13,
                          color: Colors.black45,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final target = _queryCtrl.text.trim();
                    if (target.isEmpty) return;
                    _sendRequest(target);
                    _queryCtrl.clear();
                    setState(() {});
                  },
                  child: Container(
                    width: 52,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/ui/btn_verde.png'),
                        fit: BoxFit.fill,
                      ),
                    ),
                    child: const Icon(Icons.search, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Lista de resultados. Si no hay entradas (sin query y sin amigos
            // online ni pendientes) mostramos un texto guía.
            SizedBox(
              height: 320,
              child: entries.isEmpty
                  ? const Center(
                      child: Text(
                        'Escribe el nombre de un\njugador para enviarle una solicitud',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Retro Gaming',
                          fontSize: 12,
                          color: Colors.white54,
                          height: 1.5,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        return _SearchRow(
                          username: entry.username,
                          status: entry.status,
                          onAnyadir: entry.status == _SearchRowStatus.anyadir
                              ? () {
                                  _sendRequest(entry.username);
                                  _queryCtrl.clear();
                                  setState(() {});
                                }
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Estados posibles de cada fila del buscador.
enum _SearchRowStatus { anyadir, pendiente, amigo }

class _FriendSearchEntry {
  final String username;
  final _SearchRowStatus status;
  const _FriendSearchEntry({required this.username, required this.status});
}

// Fila de la lista: nombre a la izquierda + chip de estado a la derecha.
// Solo el chip "Añadir" es interactivo (dispara send_request vía el WS de sesión).
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
