import 'package:flutter/material.dart';

abstract final class AuthColors {
  static const stage = Color(0xFFE4E2D8);
  static const paper = Color(0xFFFAF8F1);
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF5D5A4E);
  static const lime = Color(0xFFB8F23A);
  static const orange = Color(0xFFFF7A1A);
}

class AuthPageFrame extends StatelessWidget {
  const AuthPageFrame({
    super.key,
    required this.badgeTop,
    required this.badgeBottom,
    required this.child,
  });

  final String badgeTop;
  final String badgeBottom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const fontFamily = 'sans-serif';
    return Theme(
      data: theme.copyWith(
        textTheme: theme.textTheme.apply(fontFamily: fontFamily),
        primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: fontFamily),
      ),
      child: Scaffold(
        backgroundColor: AuthColors.stage,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 780),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AuthColors.paper,
                    border: Border.all(color: AuthColors.ink, width: 3),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(color: AuthColors.ink, offset: Offset(8, 8)),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      child,
                      Positioned(
                        top: 40,
                        right: 0,
                        child: AuthPromoBadge(
                          top: badgeTop,
                          bottom: badgeBottom,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AuthColors.lime,
            border: Border.all(color: AuthColors.ink, width: 2.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.restaurant_menu,
            color: AuthColors.ink,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Restaurant Fast',
          style: TextStyle(
            color: AuthColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class AuthPageHeading extends StatelessWidget {
  const AuthPageHeading({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final InlineSpan title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 270,
          child: Text.rich(
            title,
            style: const TextStyle(
              color: AuthColors.ink,
              fontSize: 42,
              height: 0.96,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.7,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 260,
          child: Text(
            subtitle,
            style: const TextStyle(
              color: AuthColors.muted,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class AuthPromoBadge extends StatelessWidget {
  const AuthPromoBadge({super.key, required this.top, required this.bottom});

  final String top;
  final String bottom;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 108,
        height: 108,
        decoration: BoxDecoration(
          color: AuthColors.orange,
          shape: BoxShape.circle,
          border: Border.all(color: AuthColors.ink, width: 3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              top,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AuthColors.ink,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AuthColors.lime,
                shape: BoxShape.circle,
                border: Border.all(color: AuthColors.ink, width: 2.5),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              bottom,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AuthColors.ink,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hintText,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.autocorrect = true,
    this.enabled = true,
    this.obscureText = false,
    this.onToggleObscure,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enabled;
  final bool obscureText;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: AuthColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          autocorrect: autocorrect,
          enableSuggestions: !obscureText,
          obscureText: obscureText,
          style: const TextStyle(
            color: AuthColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: AuthColors.muted.withValues(alpha: 0.75),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            suffixIcon: onToggleObscure == null
                ? null
                : TextButton(
                    onPressed: onToggleObscure,
                    style: TextButton.styleFrom(
                      foregroundColor: AuthColors.ink,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 48),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      obscureText ? 'VER' : 'OCULTAR',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuthColors.ink, width: 2.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuthColors.ink, width: 2.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AuthColors.ink, width: 2.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFB3261E), width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFB3261E), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: AuthColors.ink, offset: Offset(5, 5)),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AuthColors.lime,
          foregroundColor: AuthColors.ink,
          disabledBackgroundColor: AuthColors.lime,
          disabledForegroundColor: AuthColors.ink.withValues(alpha: 0.55),
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AuthColors.ink, width: 2.5),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AuthColors.ink,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: AuthColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }
}

class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.label,
    required this.onPressed,
  });

  final String question;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: const TextStyle(color: AuthColors.ink, fontSize: 14),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AuthColors.ink,
            backgroundColor: AuthColors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: const BorderSide(color: AuthColors.ink, width: 2.5),
            shape: const StadiumBorder(),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
