import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'qr_provision_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewState state) async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(authStateProvider.notifier);
    if (state.pinMode) {
      await notifier.loginWithPin(
        email: _emailController.text.trim(),
        pin: _pinController.text.trim(),
      );
    } else {
      await notifier.loginWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final busy = authState.status == AuthStatus.authenticating;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cosmic Forge POS Login',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required.';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    if (!authState.pinMode)
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required.';
                          }
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'PIN',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'PIN is required.';
                          }
                          if (value.length < 4 || value.length > 8) {
                            return 'PIN must be 4-8 digits.';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 8),
                    Text(
                      authState.pinMode
                          ? 'PIN login is optional and requires a server-side verification function.'
                          : 'Password policy: 8+ chars with uppercase, number, and special character.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    if (authState.errorMessage != null)
                      Text(
                        authState.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    if (authState.errorMessage != null)
                      const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: busy ? null : () => _submit(authState),
                      child: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(authState.pinMode
                              ? 'Sign In With PIN'
                              : 'Sign In'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              ref
                                  .read(authStateProvider.notifier)
                                  .togglePinMode();
                            },
                      child: Text(authState.pinMode
                          ? 'Use Email + Password'
                          : 'Use PIN Login'),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const QRProvisionScreen(),
                                ),
                              );
                            },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Zero-Touch Device Onboarding'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
