import 'package:flutter/material.dart';
import '../../../../core/widgets/retro_widgets.dart';

class PasswordChangeModal extends StatefulWidget {
  const PasswordChangeModal({super.key});

  @override
  State<PasswordChangeModal> createState() => _PasswordChangeModalState();
}

class _PasswordChangeModalState extends State<PasswordChangeModal> {
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

  @override
  Widget build(BuildContext context) {
    // Basándonos en RetroField de core/widgets/retro_widgets.dart
    const fieldW = 320.0;
    const fieldH = 45.0;
    const labelSize = 14.0;
    const inputSize = 16.0;

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
              onSubmitted: () => FocusScope.of(context).requestFocus(_newPassFocus),
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
              onSubmitted: () => FocusScope.of(context).requestFocus(_confirmPassFocus),
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
              onSubmitted: () {
                // TODO: Integración real con backend
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RetroImgButton(
                  label: 'CANCELAR',
                  asset: 'assets/images/ui/btn_rojo.png',
                  width: 140,
                  height: 50,
                  fontSize: 14,
                  onTap: () => Navigator.of(context).pop(),
                ),
                RetroImgButton(
                  label: 'GUARDAR',
                  asset: 'assets/images/ui/btn_morado.png',
                  width: 140,
                  height: 50,
                  fontSize: 14,
                  onTap: () {
                    // TODO: Integración real con backend
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
