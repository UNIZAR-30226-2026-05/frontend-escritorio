import 'package:flutter/material.dart';
import '../../../../core/widgets/retro_widgets.dart';

class RulesModal extends StatefulWidget {
  const RulesModal({super.key});

  @override
  State<RulesModal> createState() => _RulesModalState();
}

class _RulesModalState extends State<RulesModal> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
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
            // Título
            const Text(
              'NORMAS',
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 28,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.white, blurRadius: 10),
                  Shadow(color: Colors.white70, blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Contenido escroleable
            Container(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RuleSection(
                        title: 'OBJETIVO',
                        content: 'Sé el jugador con más monedas al final de la partida.',
                      ),
                      _RuleSection(
                        title: 'TURNO',
                        content: 'En tu turno tira los dados para avanzar casillas. La posición en el orden de turno se decide con el minijuego de reflejos.',
                      ),
                      _RuleSection(
                        title: 'CASILLAS',
                        content: 'Cada casilla tiene un efecto: pueden darte o quitarte monedas, mover tu posición, bloquearte un turno o activar un minijuego.',
                      ),
                      _RuleSection(
                        title: 'TIENDA',
                        content: 'Antes de tirar puedes comprar objetos con tus monedas. Los objetos se usan al instante.',
                      ),
                      _RuleSection(
                        title: 'OBJETOS',
                        content: '• Avanzar Casillas (1c) - Avanza una casilla extra. Solo antes de tirar.\n'
                                '• Mejorar Dados (3c) - Mejora tu segundo dado un nivel para la tirada.\n'
                                '• Barrera (10c) - Penaliza un turno al Jugador elegido.\n'
                                '• Salvavidas movimiento (5c) - Anula el efecto de una casilla de movimiento.\n'
                                '• Salvavidas bloqueo (10c) - Anula el efecto de una casilla de bloqueo.',
                      ),
                      _RuleSection(
                        title: 'DADOS',
                        content: 'El jugador con mejor resultado en el minijuego obtiene el dado de oro (el mejor). Hay dados de oro, plata, bronce y normal.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Botón cerrar
            RetroImgButton(
              label: 'CERRAR',
              asset: 'assets/images/ui/btn_morado.png',
              width: 150,
              height: 50,
              fontSize: 16,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  final String title;
  final String content;

  const _RuleSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: 18,
              color: Colors.white,
              decoration: TextDecoration.underline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontFamily: 'Retro Gaming',
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
