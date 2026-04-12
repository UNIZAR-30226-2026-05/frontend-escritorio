import 'package:flutter/material.dart';

class RetroField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final String? errorText;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;
  final double fieldWidth;
  final double fieldHeight;
  final double labelFontSize;
  final double inputFontSize;

  const RetroField({
    super.key,
    required this.label,
    required this.controller,
    required this.fieldWidth,
    required this.fieldHeight,
    required this.labelFontSize,
    required this.inputFontSize,
    this.obscureText = false,
    this.errorText,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Retro Gaming',
            fontSize: labelFontSize,
            color: const Color(0xFF1a1a2e),
            shadows: const [
              Shadow(color: Colors.white, blurRadius: 10),
              Shadow(color: Colors.white70, blurRadius: 4),
            ],
          ),
        ),
        SizedBox(height: fieldHeight * 0.15),
        Container(
          width: fieldWidth,
          height: fieldHeight,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/ui/rellenable.png'),
              fit: BoxFit.fill,
            ),
          ),
          child: Center(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              textInputAction: textInputAction,
              onSubmitted: (_) => onSubmitted?.call(),
              style: TextStyle(
                fontFamily: 'Retro Gaming',
                fontSize: inputFontSize,
                color: const Color(0xFF1a1a2e),
              ),
              cursorColor: const Color(0xFF6B21A8),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: fieldWidth * 0.06,
                ),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: EdgeInsets.only(top: fieldHeight * 0.12),
            child: Text(
              errorText!,
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Retro Gaming',
                fontSize: labelFontSize * 0.8,
              ),
            ),
          ),
      ],
    );
  }
}
