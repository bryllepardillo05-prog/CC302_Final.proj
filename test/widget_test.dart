import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_project/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _signIn(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.byKey(const ValueKey('login-email')), email);
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    password,
  );
  await tester.tap(find.byKey(const ValueKey('login-submit')));
  await tester.pumpAndSettle();
}

Future<void> _signUp(
  WidgetTester tester, {
  required String name,
  required String email,
  required String password,
}) async {
  await tester.tap(find.byKey(const ValueKey('toggle-auth-mode')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('signup-name')), name);
  await tester.enterText(find.byKey(const ValueKey('login-email')), email);
  await tester.enterText(
    find.byKey(const ValueKey('login-password')),
    password,
  );
  await tester.enterText(
    find.byKey(const ValueKey('signup-confirm-password')),
    password,
  );
  await tester.tap(find.byKey(const ValueKey('login-submit')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AmbulanceLink app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const AmbulanceLinkApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to AmbulanceLink'), findsOneWidget);
    expect(find.text('Demo accounts'), findsNothing);
    expect(find.text('user@med.com'), findsNothing);
    expect(find.text('admin@med.com'), findsNothing);
    await _signIn(tester, email: 'admin@med.com', password: 'password123');
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Hospital admin'), findsOneWidget);
  });

  testWidgets('users can sign up and sign in with a saved account', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AmbulanceLinkApp());
    await tester.pumpAndSettle();
    await _signUp(
      tester,
      name: 'New User',
      email: 'new.user@example.com',
      password: 'safe-password-123',
    );

    expect(find.text('User'), findsOneWidget);
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();

    await _signIn(
      tester,
      email: 'NEW.USER@example.com',
      password: 'safe-password-123',
    );
    expect(find.text('User'), findsOneWidget);
    expect(find.text('Welcome to AmbulanceLink'), findsNothing);
  });

  testWidgets('incorrect credentials stay on the sign-in form', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AmbulanceLinkApp());
    await tester.pumpAndSettle();

    await _signIn(tester, email: 'user@med.com', password: 'incorrect');

    expect(find.byKey(const ValueKey('login-error')), findsOneWidget);
    expect(find.text('Welcome to AmbulanceLink'), findsOneWidget);
  });

  testWidgets('user account can request and view but not manage resources', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AmbulanceLinkApp());
    await tester.pumpAndSettle();
    await _signUp(
      tester,
      name: 'Requesting User',
      email: 'requester@example.com',
      password: 'safe-password-123',
    );

    expect(find.text('User'), findsOneWidget);
    final navigationBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navigationBar, matching: find.text('Hospitals')),
      findsNothing,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Ambulances')),
      findsNothing,
    );
    expect(
      find.descendant(of: navigationBar, matching: find.text('Drivers')),
      findsNothing,
    );
    expect(find.text('REQUEST AMBULANCE'), findsOneWidget);

    await tester.tap(find.text('Requests'));
    await tester.pumpAndSettle();
    expect(find.text('Emergency Requests'), findsWidgets);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to AmbulanceLink'), findsOneWidget);
  });

  testWidgets('ambulances and drivers can be added', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AmbulanceLinkApp());
    await tester.pumpAndSettle();
    await _signIn(tester, email: 'admin@med.com', password: 'password123');

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Ambulances'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Add Ambulances'),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Plate number'),
      'AMB-TEST',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ambulance type'),
      'Advanced Life Support',
    );
    await tester.tap(find.text('Add record'));
    await tester.pumpAndSettle();
    expect(find.text('AMB-TEST'), findsOneWidget);

    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .hideCurrentSnackBar();
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Drivers'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Drivers'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Driver name'),
      'Test Driver',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contact number'),
      '09123456789',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'License reference'),
      'DL-TEST',
    );
    await tester.tap(find.text('Add record'));
    await tester.pumpAndSettle();
    expect(find.text('Test Driver'), findsOneWidget);
  });
}
