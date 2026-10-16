import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color primaryBlue = Color(0xFF155EEF);
const Color darkNavy = Color(0xFF14213D);
const Color pageBackground = Color(0xFFF4F7FC);
const Color mutedText = Color(0xFF667085);
const Color cardBorder = Color(0xFFE7ECF3);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AmbulanceLinkApp());
}

class AmbulanceLinkApp extends StatelessWidget {
  const AmbulanceLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AmbulanceLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: pageBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: pageBackground,
          foregroundColor: darkNavy,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: darkNavy,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: cardBorder),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFD),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryBlue, width: 1.6),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 4,
          indicatorColor: const Color(0xFFE7EEFF),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: primaryBlue,
              );
            }
            return const TextStyle(fontSize: 11, color: mutedText);
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

enum AccountRole { user, hospitalAdmin }

class DemoAuth {
  static const _accountsKey = 'ambulance_link_user_accounts';

  static String _passwordHash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  static Future<List<Map<String, dynamic>>> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Saved user accounts are invalid.');
    }

    return decoded.map((account) {
      if (account is! Map) {
        throw const FormatException('Saved user accounts are invalid.');
      }
      return Map<String, dynamic>.from(account);
    }).toList();
  }

  static Future<AccountRole?> authenticate(
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail == 'admin@med.com') {
      return password == 'password123' ? AccountRole.hospitalAdmin : null;
    }
    final accounts = await _loadAccounts();
    for (final account in accounts) {
      if (account['email'] == normalizedEmail &&
          account['passwordHash'] ==
              _passwordHash(account['salt']?.toString() ?? '', password)) {
        return AccountRole.user;
      }
    }
    return null;
  }

  static Future<bool> createUser({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final accounts = await _loadAccounts();
    if (normalizedEmail == 'admin@med.com' ||
        accounts.any((account) => account['email'] == normalizedEmail)) {
      return false;
    }

    final random = Random.secure();
    final salt = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    accounts.add({
      'name': name.trim(),
      'email': normalizedEmail,
      'salt': salt,
      'passwordHash': _passwordHash(salt, password),
    });

    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_accountsKey, jsonEncode(accounts));
    if (!saved) {
      throw StateError('Unable to save this account on the device.');
    }
    return true;
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AccountRole? _role;

  @override
  Widget build(BuildContext context) {
    final role = _role;
    if (role == null) {
      return LoginScreen(
        onLogin: (accountRole) => setState(() => _role = accountRole),
      );
    }
    return MainScreen(
      key: ValueKey(role),
      role: role,
      onLogout: () => setState(() => _role = null),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final ValueChanged<AccountRole> onLogin;

  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSigningUp = false;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      if (_isSigningUp) {
        final created = await DemoAuth.createUser(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!created) {
          setState(
            () => _errorMessage = 'An account with this email already exists.',
          );
          return;
        }
        widget.onLogin(AccountRole.user);
      } else {
        final role = await DemoAuth.authenticate(
          _emailController.text,
          _passwordController.text,
        );
        if (role == null) {
          setState(() => _errorMessage = 'Email or password is incorrect.');
          return;
        }
        widget.onLogin(role);
      }
    } catch (error) {
      setState(
        () => _errorMessage = _isSigningUp
            ? 'Unable to create account: $error'
            : 'Unable to sign in: $error',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isSigningUp = !_isSigningUp;
      _errorMessage = null;
      _formKey.currentState?.reset();
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_outlined,
                      color: primaryBlue,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Welcome to AmbulanceLink',
                    style: TextStyle(
                      color: darkNavy,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSigningUp
                        ? 'Create an account to request ambulance services.'
                        : 'Sign in to request or manage ambulance services.',
                    style: TextStyle(color: mutedText, height: 1.5),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isSigningUp ? 'Create your account' : 'Sign in',
                            style: TextStyle(
                              color: darkNavy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_isSigningUp) ...[
                            const SizedBox(height: 18),
                            TextFormField(
                              key: const ValueKey('signup-name'),
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (!_isSigningUp) return null;
                                if (value == null || value.trim().isEmpty) {
                                  return 'Enter your full name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                          ] else
                            const SizedBox(height: 18),
                          TextFormField(
                            key: const ValueKey('login-email'),
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.email_outlined),
                              hintText: 'name@example.com',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your email address';
                              }
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(value.trim())) {
                                return 'Enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            key: const ValueKey('login-password'),
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Show password'
                                    : 'Hide password',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter your password';
                              }
                              if (_isSigningUp && value.length < 8) {
                                return 'Use at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          if (_isSigningUp) ...[
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const ValueKey('signup-confirm-password'),
                              controller: _confirmPasswordController,
                              decoration: const InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: Icon(Icons.lock_reset_outlined),
                              ),
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              validator: (value) {
                                if (!_isSigningUp) return null;
                                if (value == null || value.isEmpty) {
                                  return 'Confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              key: const ValueKey('login-error'),
                              style: const TextStyle(
                                color: Color(0xFFB42318),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const ValueKey('login-submit'),
                            onPressed: _submitting ? null : _submit,
                            icon: const Icon(Icons.login),
                            label: Text(
                              _submitting
                                  ? 'Please wait...'
                                  : _isSigningUp
                                  ? 'Create account'
                                  : 'Sign in',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            key: const ValueKey('toggle-auth-mode'),
                            onPressed: _submitting ? null : _toggleMode,
                            child: Text(
                              _isSigningUp
                                  ? 'Already have an account? Sign in'
                                  : "Don't have an account? Sign up",
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'User accounts are saved on this device. Hospital admin '
                    'access is preconfigured.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: mutedText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// LOCAL STORAGE

class LocalStore {
  static const String _key = 'ambulance_link_data';

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Saved data must be a JSON object.');
      }

      final saved = Map<String, dynamic>.from(decoded);
      for (final key in const [
        'hospitals',
        'ambulances',
        'drivers',
        'requests',
      ]) {
        final value = saved[key];
        if (value == null) {
          saved[key] = <Map<String, dynamic>>[];
        } else if (value is List) {
          saved[key] = value.map((item) {
            if (item is! Map) {
              throw FormatException('Saved "$key" records are invalid.');
            }
            return Map<String, dynamic>.from(item);
          }).toList();
        } else {
          throw FormatException('Saved "$key" records are invalid.');
        }
      }
      return saved;
    }

    final initial = <String, dynamic>{
      'hospitals': [
        {
          'name': 'Sample City Hospital',
          'location': 'City Center',
          'contact': '09123456789',
        },
      ],
      'ambulances': [
        {
          'plate': 'AMB-001',
          'hospital': 'Sample City Hospital',
          'type': 'Basic Life Support',
          'status': 'Available',
        },
      ],
      'drivers': [
        {
          'name': 'Sample Driver',
          'hospital': 'Sample City Hospital',
          'contact': '09987654321',
          'license': 'DEMO-123',
          'status': 'Available',
        },
      ],
      'requests': <Map<String, dynamic>>[],
    };

    await prefs.setString(_key, jsonEncode(initial));
    return initial;
  }

  static Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data));
  }
}

// MAIN SCREEN

class MainScreen extends StatefulWidget {
  final AccountRole role;
  final VoidCallback onLogout;

  const MainScreen({super.key, required this.role, required this.onLogout});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  bool loading = true;
  String? loadError;

  Map<String, dynamic> data = {
    'hospitals': <Map<String, dynamic>>[],
    'ambulances': <Map<String, dynamic>>[],
    'drivers': <Map<String, dynamic>>[],
    'requests': <Map<String, dynamic>>[],
  };

  final List<String> titles = [
    'Dashboard',
    'Hospitals',
    'Ambulances',
    'Drivers',
    'Emergency Requests',
  ];

  bool get isHospitalAdmin => widget.role == AccountRole.hospitalAdmin;

  List<int> get visiblePageIndexes =>
      isHospitalAdmin ? [0, 1, 2, 3, 4] : [0, 4];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final result = await LocalStore.load();
      if (!mounted) return;

      setState(() {
        data = result;
        loading = false;
        loadError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        loadError = 'Unable to load saved data.';
      });
    }
  }

  List<Map<String, dynamic>> records(String key) {
    return (data[key] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<bool> saveRecords(String key, List<Map<String, dynamic>> items) async {
    try {
      final updatedData = Map<String, dynamic>.from(data)..[key] = items;
      await LocalStore.save(updatedData);
      if (!mounted) return false;

      setState(() => data = updatedData);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Changes saved successfully.'),
          ),
        );
      return true;
    } catch (error) {
      debugPrint('Failed to save "$key" records: $error');
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB42318),
          content: Text(
            'Could not save changes. Check device storage and try again. '
            'Details: $error',
          ),
        ),
      );
      return false;
    }
  }

  Future<void> addEmergencyRequest() async {
    final hospitals = records('hospitals');

    if (hospitals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a hospital first.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final requester = TextEditingController();
    final location = TextEditingController();
    final notes = TextEditingController();

    String hospital = hospitals.first['name'].toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Row(
                children: [
                  Icon(Icons.emergency, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Request an Ambulance',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: requester,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: location,
                        decoration: const InputDecoration(
                          labelText: 'Pickup address',
                          prefixIcon: Icon(Icons.location_on_outlined),
                          hintText: 'Street, barangay, or landmark',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter your location'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: hospital,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Hospital',
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                        ),
                        items: hospitals.map((h) {
                          return DropdownMenuItem<String>(
                            value: h['name'].toString(),
                            child: Text(
                              h['name'].toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() => hospital = v);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notes,
                        decoration: const InputDecoration(
                          labelText: 'Emergency details (optional)',
                          prefixIcon: Icon(Icons.notes_outlined),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This prototype saves requests on this device only. '
                        'It does not contact emergency services.',
                        style: TextStyle(color: mutedText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final newRequests = records('requests');

      newRequests.insert(0, {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        'requester': requester.text.trim(),
        'location': location.text.trim(),
        'hospital': hospital,
        'notes': notes.text.trim(),
        'status': 'Pending',
        'createdAt': DateTime.now().toIso8601String(),
      });

      final saved = await saveRecords('requests', newRequests);

      if (saved && mounted) {
        setState(() => selectedIndex = 4);
      }
    }

    requester.dispose();
    location.dispose();
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AmbulanceLink')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 56,
                  color: mutedText,
                ),
                const SizedBox(height: 12),
                Text(loadError!),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      loading = true;
                      loadError = null;
                    });
                    loadData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      buildDashboard(),
      buildCrudPage(
        title: 'Hospitals',
        keyName: 'hospitals',
        fields: const {
          'name': 'Hospital name',
          'location': 'Address / Location',
          'contact': 'Contact number',
        },
        displayField: 'name',
      ),
      buildCrudPage(
        title: 'Ambulances',
        keyName: 'ambulances',
        fields: const {
          'plate': 'Plate number',
          'hospital': 'Hospital name',
          'type': 'Ambulance type',
          'status': 'Status (Available / Dispatched / Maintenance)',
        },
        displayField: 'plate',
        hospitals: records('hospitals')
            .map((hospital) => hospital['name']?.toString() ?? '')
            .where((name) => name.trim().isNotEmpty)
            .toList(),
      ),
      buildCrudPage(
        title: 'Drivers',
        keyName: 'drivers',
        fields: const {
          'name': 'Driver name',
          'hospital': 'Hospital name',
          'contact': 'Contact number',
          'license': 'License reference',
          'status': 'Status (Available / Assigned / Offline)',
        },
        displayField: 'name',
        hospitals: records('hospitals')
            .map((hospital) => hospital['name']?.toString() ?? '')
            .where((name) => name.trim().isNotEmpty)
            .toList(),
      ),
      buildCrudPage(
        title: 'Emergency Requests',
        keyName: 'requests',
        fields: const {
          'requester': 'Requester name',
          'location': 'Pickup address',
          'hospital': 'Hospital name',
          'notes': 'Emergency details',
          'status':
              'Status (Pending / Accepted / Dispatched / Arrived / Completed / Cancelled)',
        },
        displayField: 'requester',
        hospitals: records('hospitals')
            .map((hospital) => hospital['name']?.toString() ?? '')
            .where((name) => name.trim().isNotEmpty)
            .toList(),
        readOnly: !isHospitalAdmin,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[selectedIndex]),
            const Text(
              'AmbulanceLink',
              style: TextStyle(
                fontSize: 11,
                color: mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                isHospitalAdmin ? 'Hospital admin' : 'User',
                style: const TextStyle(
                  fontSize: 12,
                  color: mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Refresh local data',
            onPressed: loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: pages),
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: addEmergencyRequest,
              backgroundColor: const Color(0xFFD92D20),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.emergency),
              label: const Text(
                'REQUEST AMBULANCE',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: visiblePageIndexes.indexOf(selectedIndex),
        onDestinationSelected: (index) {
          setState(() => selectedIndex = visiblePageIndexes[index]);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          if (isHospitalAdmin) ...[
            const NavigationDestination(
              icon: Icon(Icons.local_hospital_outlined),
              selectedIcon: Icon(Icons.local_hospital),
              label: 'Hospitals',
            ),
            const NavigationDestination(
              icon: Icon(Icons.airport_shuttle_outlined),
              selectedIcon: Icon(Icons.airport_shuttle),
              label: 'Ambulances',
            ),
            const NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: 'Drivers',
            ),
          ],
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
        ],
      ),
    );
  }

  // DASHBOARD

  Widget buildDashboard() {
    final hospitals = records('hospitals');
    final ambulances = records('ambulances');
    final drivers = records('drivers');
    final requests = records('requests');

    final availableAmbulances = ambulances
        .where((a) => a['status'] == 'Available')
        .length;

    final availableDrivers = drivers
        .where((d) => d['status'] == 'Available')
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF155EEF), Color(0xFF1849A9), Color(0xFF14213D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -12,
                top: 8,
                child: Icon(
                  Icons.health_and_safety,
                  size: 116,
                  color: Colors.white.withValues(alpha: 0.09),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, color: Colors.white, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'CARE WHEN IT MATTERS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Welcome to',
                    style: TextStyle(color: Color(0xFFD9E5FF), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'AmbulanceLink',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Manage hospital information, ambulance '
                    'availability, drivers, and emergency requests.',
                    style: TextStyle(
                      color: Color(0xFFE5EDFF),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 17,
                      ),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'Simple. Organized. Easy to use.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        const SectionHeading(
          title: 'Overview',
          subtitle: 'Your current records at a glance',
          icon: Icons.analytics_outlined,
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: MediaQuery.sizeOf(context).width < 400 ? 1.0 : 1.25,
          children: [
            summaryCard(
              'Hospitals',
              hospitals.length,
              Icons.local_hospital_outlined,
              const Color(0xFF155EEF),
              const Color(0xFFEAF1FF),
            ),
            summaryCard(
              'Available Ambulances',
              availableAmbulances,
              Icons.airport_shuttle_outlined,
              const Color(0xFF039855),
              const Color(0xFFE7F8EF),
            ),
            summaryCard(
              'Available Drivers',
              availableDrivers,
              Icons.badge_outlined,
              const Color(0xFFDC6803),
              const Color(0xFFFFF2E2),
            ),
            summaryCard(
              'Total Requests',
              requests.length,
              Icons.assignment_outlined,
              const Color(0xFFD92D20),
              const Color(0xFFFFE9E7),
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            const Expanded(
              child: SectionHeading(
                title: 'Recent Requests',
                subtitle: 'Latest emergency records',
                icon: Icons.history_rounded,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => selectedIndex = 4),
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cardBorder),
            ),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFEAF1FF),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: primaryBlue,
                    size: 29,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'No requests yet',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                SizedBox(height: 5),
                Text(
                  'Your recent requests will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: mutedText),
                ),
              ],
            ),
          )
        else
          ...requests.take(3).map((r) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RequestPreviewCard(
                requester: r['requester']?.toString() ?? 'Unknown',
                location: r['location']?.toString() ?? '',
                status: r['status']?.toString() ?? 'Pending',
                onTap: () => setState(() => selectedIndex = 4),
              ),
            );
          }),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF5DCA0)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Color(0xFF9A6700)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Demo app: data is stored locally on this device. '
                  'For a real emergency, contact your local emergency '
                  'services directly.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF7A5700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget summaryCard(
    String title,
    int count,
    IconData icon,
    Color color,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 26,
              height: 1,
              fontWeight: FontWeight.w900,
              color: darkNavy,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: mutedText,
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCrudPage({
    required String title,
    required String keyName,
    required Map<String, String> fields,
    required String displayField,
    List<String> hospitals = const [],
    bool readOnly = false,
  }) {
    final items = records(keyName);

    return RecordsPage(
      title: title,
      items: items,
      fields: fields,
      displayField: displayField,
      hospitals: hospitals,
      readOnly: readOnly,
      onChanged: (updated) async {
        await saveRecords(keyName, updated);
      },
    );
  }
}

// REUSABLE UI COMPONENTS

class SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: primaryBlue, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  color: darkNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final value = status.toLowerCase();

    Color color = const Color(0xFF475467);
    Color background = const Color(0xFFF2F4F7);

    if (value == 'available' || value == 'completed' || value == 'arrived') {
      color = const Color(0xFF027A48);
      background = const Color(0xFFE7F8EF);
    } else if (value == 'pending') {
      color = const Color(0xFFB54708);
      background = const Color(0xFFFFF2E2);
    } else if (value == 'accepted' ||
        value == 'dispatched' ||
        value == 'assigned') {
      color = const Color(0xFF155EEF);
      background = const Color(0xFFEAF1FF);
    } else if (value == 'cancelled' ||
        value == 'maintenance' ||
        value == 'offline') {
      color = const Color(0xFFB42318);
      background = const Color(0xFFFFE9E7);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class RequestPreviewCard extends StatelessWidget {
  final String requester;
  final String location;
  final String status;
  final VoidCallback onTap;

  const RequestPreviewCard({
    super.key,
    required this.requester,
    required this.location,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 23,
                backgroundColor: Color(0xFFFFE9E7),
                child: Icon(Icons.emergency_outlined, color: Color(0xFFD92D20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requester,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: darkNavy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      location,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: mutedText, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    StatusBadge(status: status),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

// RECORDS: ADD, EDIT, DELETE

class RecordsPage extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Map<String, String> fields;
  final String displayField;
  final List<String> hospitals;
  final bool readOnly;
  final Future<void> Function(List<Map<String, dynamic>>) onChanged;

  const RecordsPage({
    super.key,
    required this.title,
    required this.items,
    required this.fields,
    required this.displayField,
    this.hospitals = const [],
    this.readOnly = false,
    required this.onChanged,
  });

  IconData get pageIcon {
    switch (title) {
      case 'Hospitals':
        return Icons.local_hospital_outlined;
      case 'Ambulances':
        return Icons.airport_shuttle_outlined;
      case 'Drivers':
        return Icons.badge_outlined;
      default:
        return Icons.assignment_outlined;
    }
  }

  Future<void> editRecord(
    BuildContext context, {
    Map<String, dynamic>? existing,
    int? index,
  }) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return _RecordEditorDialog(
          title: title,
          fields: fields,
          hospitals: hospitals,
          existing: existing,
        );
      },
    );

    if (values != null) {
      final updated = items
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      final record = existing == null
          ? <String, dynamic>{
              'id': DateTime.now().microsecondsSinceEpoch.toString(),
              'createdAt': DateTime.now().toIso8601String(),
            }
          : Map<String, dynamic>.from(existing);

      for (final field in fields.keys) {
        record[field] = values[field]!;
      }

      if (index == null) {
        updated.insert(0, record);
      } else {
        updated[index] = record;
      }

      await onChanged(updated);
    }
  }

  Future<void> deleteRecord(BuildContext context, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 10),
            Text('Delete record?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this record? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD92D20),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = items
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      updated.removeAt(index);
      await onChanged(updated);
    }
  }

  String _prettyLabel(String key) {
    switch (key) {
      case 'name':
        return 'Name';
      case 'requester':
        return 'Requester';
      case 'location':
        return 'Location';
      case 'contact':
        return 'Contact';
      case 'hospital':
        return 'Hospital';
      case 'plate':
        return 'Plate number';
      case 'type':
        return 'Ambulance type';
      case 'license':
        return 'License';
      case 'status':
        return 'Status';
      case 'notes':
        return 'Emergency details';
      case 'createdAt':
        return 'Created at';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => editRecord(context),
              icon: const Icon(Icons.add),
              label: Text('Add $title'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(pageIcon, color: primaryBlue, size: 27),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: darkNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${items.length} record${items.length == 1 ? '' : 's'} saved',
                          style: const TextStyle(
                            fontSize: 12,
                            color: mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length}',
                      style: const TextStyle(
                        color: primaryBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEAF1FF),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(pageIcon, size: 42, color: primaryBlue),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'No $title records yet',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: darkNavy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the button below to add your first record.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: mutedText,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (!readOnly)
                            FilledButton.icon(
                              onPressed: () => editRecord(context),
                              icon: const Icon(Icons.add),
                              label: Text('Add $title'),
                            ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final name =
                          item[displayField]?.toString() ?? 'Unnamed record';

                      final details = item.entries
                          .where(
                            (entry) =>
                                entry.key != displayField &&
                                entry.key != 'id' &&
                                entry.key != 'createdAt' &&
                                entry.value.toString().trim().isNotEmpty,
                          )
                          .toList();

                      final status = item['status']?.toString();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF1FF),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      pageIcon,
                                      color: primaryBlue,
                                      size: 25,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: darkNavy,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        if (status != null)
                                          StatusBadge(status: status),
                                      ],
                                    ),
                                  ),
                                  if (!readOnly)
                                    PopupMenuButton<String>(
                                      tooltip: 'More options',
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          editRecord(
                                            context,
                                            existing: item,
                                            index: index,
                                          );
                                        } else if (action == 'delete') {
                                          deleteRecord(context, index);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.edit_outlined,
                                                size: 19,
                                              ),
                                              SizedBox(width: 10),
                                              Text('Edit'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                size: 19,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 10),
                                              Text('Delete'),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              if (details.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                const Divider(height: 1, color: cardBorder),
                                const SizedBox(height: 12),
                                ...details.map((entry) {
                                  final value = entry.value.toString();
                                  final isStatus = entry.key == 'status';

                                  if (isStatus) {
                                    return const SizedBox.shrink();
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 9),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 112,
                                          child: Text(
                                            _prettyLabel(entry.key),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: mutedText,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            value,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.4,
                                              color: darkNavy,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecordEditorDialog extends StatefulWidget {
  final String title;
  final Map<String, String> fields;
  final List<String> hospitals;
  final Map<String, dynamic>? existing;

  const _RecordEditorDialog({
    required this.title,
    required this.fields,
    required this.hospitals,
    required this.existing,
  });

  @override
  State<_RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<_RecordEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields.keys)
        field: TextEditingController(text: _initialValue(field)),
    };
  }

  String _initialValue(String field) {
    final existing = widget.existing;
    if (existing != null) return existing[field]?.toString() ?? '';
    if (field == 'hospital' && widget.hospitals.isNotEmpty) {
      return widget.hospitals.first;
    }
    if (field == 'status') {
      return widget.title == 'Emergency Requests' ? 'Pending' : 'Available';
    }
    return '';
  }

  List<String> _choicesFor(String field) {
    List<String> choices;
    if (field == 'hospital' && widget.hospitals.isNotEmpty) {
      choices = List<String>.from(widget.hospitals);
    } else if (field == 'status') {
      choices = switch (widget.title) {
        'Ambulances' => ['Available', 'Dispatched', 'Maintenance'],
        'Drivers' => ['Available', 'Assigned', 'Offline'],
        'Emergency Requests' => [
          'Pending',
          'Accepted',
          'Dispatched',
          'Arrived',
          'Completed',
          'Cancelled',
        ],
        _ => const [],
      };
    } else {
      return const [];
    }

    final currentValue = widget.existing?[field]?.toString();
    if (currentValue != null &&
        currentValue.isNotEmpty &&
        !choices.contains(currentValue)) {
      choices.add(currentValue);
    }
    return choices;
  }

  IconData _fieldIcon(String field) {
    switch (field) {
      case 'name':
      case 'requester':
        return Icons.person_outline;
      case 'location':
        return Icons.location_on_outlined;
      case 'contact':
        return Icons.phone_outlined;
      case 'hospital':
        return Icons.local_hospital_outlined;
      case 'plate':
        return Icons.confirmation_number_outlined;
      case 'type':
        return Icons.medical_services_outlined;
      case 'license':
        return Icons.badge_outlined;
      case 'status':
        return Icons.circle_outlined;
      case 'notes':
        return Icons.notes_outlined;
      default:
        return Icons.edit_note_outlined;
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Map<String, String>.fromEntries(
        _controllers.entries.map(
          (entry) => MapEntry(entry.key, entry.value.text.trim()),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdding = widget.existing == null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        isAdding ? 'Add ${widget.title}' : 'Edit ${widget.title}',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.hospitals.isEmpty &&
                    widget.fields.containsKey('hospital') &&
                    widget.title != 'Hospitals')
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No hospitals saved yet. You can enter the hospital '
                      'name now, or add hospitals first for a selection list.',
                      style: TextStyle(
                        color: Color(0xFF7A5700),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ...widget.fields.entries.map((field) {
                  final choices = _choicesFor(field.key);
                  final controller = _controllers[field.key]!;
                  final fieldWidget = choices.isNotEmpty
                      ? DropdownButtonFormField<String>(
                          initialValue: choices.contains(controller.text)
                              ? controller.text
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: field.value,
                            prefixIcon: Icon(_fieldIcon(field.key)),
                          ),
                          items: choices
                              .map(
                                (choice) => DropdownMenuItem(
                                  value: choice,
                                  child: Text(
                                    choice,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) controller.text = value;
                          },
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Choose an option'
                              : null,
                        )
                      : TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: field.value,
                            prefixIcon: Icon(_fieldIcon(field.key)),
                            alignLabelWithHint: field.key == 'notes',
                          ),
                          maxLines: field.key == 'notes' ? 3 : 1,
                          keyboardType: field.key == 'contact'
                              ? TextInputType.phone
                              : TextInputType.text,
                          textCapitalization:
                              field.key == 'contact' ||
                                  field.key == 'license' ||
                                  field.key == 'plate'
                              ? TextCapitalization.characters
                              : TextCapitalization.words,
                          validator: (value) {
                            if (field.key == 'notes') return null;
                            if (value == null || value.trim().isEmpty) {
                              return 'This field is required';
                            }
                            return null;
                          },
                        );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: fieldWidget,
                  );
                }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(isAdding ? 'Add record' : 'Save changes'),
        ),
      ],
    );
  }
}
