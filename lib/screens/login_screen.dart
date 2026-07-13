import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _scrollCtrl = ScrollController();

  // Keys to find exact widget position for ensureVisible
  final _passFieldKey = GlobalKey();
  final _signInBtnKey = GlobalKey();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  static const _validUser = 'emedge';
  static const _validPass = 'emedge123';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? AppColors.backgroundDark : AppColors.background;
  Color get _surface => _isDark ? AppColors.surfaceDark : AppColors.surface;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  Color get _border => _isDark ? AppColors.borderDark : AppColors.border;

  @override
  void initState() {
    super.initState();

    // When password field gets focus → scroll Sign In button into view
    _passFocus.addListener(() {
      if (_passFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          // Scroll to Sign In button so it is fully visible above keyboard
          if (_signInBtnKey.currentContext != null) {
            Scrollable.ensureVisible(
              _signInBtnKey.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 1.0, // align bottom of button to bottom of viewport
            );
          }
        });
      }
    });

    // When username field gets focus → scroll password into view
    _userFocus.addListener(() {
      if (_userFocus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          if (_passFieldKey.currentContext != null) {
            Scrollable.ensureVisible(
              _passFieldKey.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: 0.8,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    if (_userCtrl.text.trim() == _validUser && _passCtrl.text == _validPass) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        _loading = false;
        _error = 'Invalid username or password';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      // KEY FIX: true — body shrinks when keyboard appears
      // SingleChildScrollView handles the rest
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 48),

                // ── Logo ──────────────────────────────────────
                Image.asset(
                  'assets/icon/emc_icon.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: AppColors.primary, size: 40),
                  ),
                ),
                const SizedBox(height: 16),

                const Text("EMEDGE",
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 3)),
                Text("MASTERCONTROLLER",
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _textSecondary,
                        letterSpacing: 3)),

                const SizedBox(height: 32),

                // ── Card ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Sign In",
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary)),
                      const SizedBox(height: 4),
                      Text("Enter your credentials to continue",
                          style:
                              TextStyle(fontSize: 12, color: _textSecondary)),
                      const SizedBox(height: 24),

                      // ── Username ────────────────────────────
                      Text("Username",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _textSecondary)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _userCtrl,
                        focusNode: _userFocus,
                        style: TextStyle(color: _textPrimary),
                        textInputAction: TextInputAction.next,
                        scrollPadding: const EdgeInsets.only(bottom: 350),
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_passFocus),
                        decoration: const InputDecoration(
                          hintText: "Enter username",
                          prefixIcon: Icon(Icons.person_outline_rounded,
                              color: AppColors.primary, size: 20),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Password ────────────────────────────
                      // KeyedSubtree so ensureVisible can find it
                      KeyedSubtree(
                        key: _passFieldKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Password",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _textSecondary)),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              obscureText: _obscure,
                              style: TextStyle(color: _textPrimary),
                              textInputAction: TextInputAction.done,
                              scrollPadding: const EdgeInsets.only(bottom: 350),
                              onSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                hintText: "Enter password",
                                prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppColors.primary,
                                    size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: _textSecondary,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Error ───────────────────────────────
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.error, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.error)),
                            ),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Sign In Button ───────────────────────
                      // KeyedSubtree so ensureVisible scrolls to it
                      KeyedSubtree(
                        key: _signInBtnKey,
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : const Text("Sign In"),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Theme Toggle ────────────────────────────────
                GestureDetector(
                  onTap: () => EVSEApp.of(context)?.toggleTheme(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 16,
                        color: _textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isDark ? "Switch to Light" : "Switch to Dark",
                        style: TextStyle(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text("EMEDGE Systems Pvt. Ltd.",
                    style: TextStyle(fontSize: 11, color: _textSecondary)),
                Text("v1.0.0",
                    style: TextStyle(fontSize: 10, color: _textSecondary)),

                // Extra space so Sign In button never hides behind keyboard
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
