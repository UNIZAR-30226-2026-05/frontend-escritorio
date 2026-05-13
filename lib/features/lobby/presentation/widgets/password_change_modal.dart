import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/auth_provider.dart';
import '../../../../core/widgets/retro_widgets.dart';

class PasswordChangeModal extends ConsumerStatefulWidget {
  const PasswordChangeModal({super.key});

  @override
  ConsumerState<PasswordChangeModal> createState() => _PasswordChangeModalState();
}

class _PasswordChangeModalState extends ConsumerState<PasswordChangeModal> {
  final TextEditingController _currentPassController = TextEditingController();
  final TextEditingController _newPassController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  final FocusNode _currentPassFocus = FocusNode();
  final FocusNode _newPassFocus = FocusNode();
  final FocusNode _confirmPassFocus = FocusNode();

  @override
  void dispose() {
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _currentPassFocus.dispose();
    _newPassFocus.dispose();
    _confirmPassFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final current = _currentPassController.text;
    final newPass = _newPassController.text;
    final confirm = _confirmPassController.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rellena todos los campos')),
      );
      return;
    }

    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden')),
      );
      return;
    }

    if (newPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 8 caracteres')),
      );
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .cambiarContrasena(current, newPass);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña cambiada con éxito')),
      );
      Navigator.of(context).pop();
    } else {
      final error = ref.read(authProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const fieldW = 320.0;
    const fieldH = 45.0;
    const labelSize = 14.0;
    const inputSize = 16.0;

    final isLoading = ref.watch(authProvider).isLoading;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 450,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
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
            const Text(
              'CAMBIAR CONTRASEÑA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: 24,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.white, blurRadius: 10),
                  Shadow(color: Colors.white70, blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(height: 30),
            RetroField(
              label: 'Contraseña actual',
              controller: _currentPassController,
              focusNode: _currentPassFocus,
              fieldWidth: fieldW,
              fieldHeight: fieldH,
              labelFontSize: labelSize,
              inputFontSize: inputSize,
              obscureText: true,
              color: Colors.white,
              textInputAction: TextInputAction.next,
              onSubmitted: () =>
                  FocusScope.of(context).requestFocus(_newPassFocus),
            ),
            const SizedBox(height: 15),
            RetroField(
              label: 'Nueva contraseña',
              controller: _newPassController,
              focusNode: _newPassFocus,
              fieldWidth: fieldW,
              fieldHeight: fieldH,
              labelFontSize: labelSize,
              inputFontSize: inputSize,
              obscureText: true,
              color: Colors.white,
              textInputAction: TextInputAction.next,
              onSubmitted: () =>
                  FocusScope.of(context).requestFocus(_confirmPassFocus),
            ),
            const SizedBox(height: 15),
            RetroField(
              label: 'Confirmar nueva',
              controller: _confirmPassController,
              focusNode: _confirmPassFocus,
              fieldWidth: fieldW,
              fieldHeight: fieldH,
              labelFontSize: labelSize,
              inputFontSize: inputSize,
              obscureText: true,
              color: Colors.white,
              textInputAction: TextInputAction.done,
              onSubmitted: isLoading ? null : _handleSave,
            ),
            const SizedBox(height: 10),
            // Mostrar error si existe en el authProvider
            Consumer(
              builder: (context, ref, child) {
                final authError = ref.watch(authProvider).error;
                if (authError == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    authError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'Retro Gaming',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RetroImgButton(
                  label: 'CANCELAR',
                  asset: 'assets/images/ui/btn_rojo.png',
                  width: 140,
                  height: 50,
                  fontSize: 14,
                  onTap: isLoading ? null : () => Navigator.of(context).pop(),
                ),
                RetroImgButton(
                  label: isLoading ? '...' : 'GUARDAR',
                  asset: 'assets/images/ui/btn_morado.png',
                  width: 140,
                  height: 50,
                  fontSize: 14,
                  onTap: isLoading ? null : _handleSave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
