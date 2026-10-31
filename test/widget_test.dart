// Widget tests for the login flow.
//
// These use an in-memory FakeFirebaseFirestore pre-filled the same way the
// "users" collection is filled in the Firebase Console. They check the UI and
// the manual credential check only; the real Firestore is verified by
// tool/e2e_chrome_test.py.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_experiment_10_firestore_user_login/auth_service.dart';
import 'package:flutter_experiment_10_firestore_user_login/login_screen.dart';

/// Simulates Firestore being unreachable.
class _FailingAuthService extends AuthService {
  _FailingAuthService(FakeFirebaseFirestore db)
    : super(users: db.collection('users'));

  @override
  Future<AppUser?> login(String email, String password) async =>
      throw const LoginException(
        'Database error (unavailable). Please try again.',
      );
}

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    final users = firestore.collection('users');
    // Hashed password (recommended).
    await users.add({
      'name': 'Yokeshwaran',
      'email': 'yokesh@example.com',
      'phone': '9876543210',
      'password': hashPassword('Pass@123'),
    });
    // Plain-text password (also allowed by the exercise).
    await users.add({
      'name': 'Priya',
      'email': 'priya@example.com',
      'phone': '9123456780',
      'password': 'priya123',
    });
  });

  Future<void> pumpLogin(WidgetTester tester, {AuthService? service}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authService:
              service ?? AuthService(users: firestore.collection('users')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final emailField = find.widgetWithText(TextFormField, 'Email');
  final passwordField = find.widgetWithText(TextFormField, 'Password');
  final loginButton = find.widgetWithText(ElevatedButton, 'Login');

  Future<void> login(WidgetTester tester, String email, String password) async {
    await tester.enterText(emailField, email);
    await tester.enterText(passwordField, password);
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
  }

  testWidgets('login screen shows title, fields and button', (tester) async {
    await pumpLogin(tester);
    expect(find.text('User Login'), findsOneWidget);
    expect(emailField, findsOneWidget);
    expect(passwordField, findsOneWidget);
    expect(loginButton, findsOneWidget);
  });

  testWidgets('valid hashed credentials open the dashboard', (tester) async {
    await pumpLogin(tester);
    await login(tester, '  Yokesh@Example.com ', 'Pass@123');

    expect(find.text('Welcome, Yokeshwaran'), findsOneWidget);
    expect(find.text('yokesh@example.com'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('User Dashboard'), findsOneWidget);
    // The stored password / hash is never shown.
    expect(find.text(hashPassword('Pass@123')), findsNothing);
    expect(find.text('Pass@123'), findsNothing);
  });

  testWidgets('valid plain-text credentials open the dashboard', (
    tester,
  ) async {
    await pumpLogin(tester);
    await login(tester, 'priya@example.com', 'priya123');
    expect(find.text('Welcome, Priya'), findsOneWidget);
  });

  testWidgets('incorrect password shows error', (tester) async {
    await pumpLogin(tester);
    await login(tester, 'yokesh@example.com', 'wrong');
    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(find.text('User Dashboard'), findsNothing);
  });

  testWidgets('hash itself is not accepted as the password', (tester) async {
    await pumpLogin(tester);
    await login(tester, 'yokesh@example.com', hashPassword('Pass@123'));
    expect(find.text('Invalid email or password'), findsOneWidget);
  });

  testWidgets('unknown email shows error', (tester) async {
    await pumpLogin(tester);
    await login(tester, 'nobody@example.com', 'Pass@123');
    expect(find.text('Invalid email or password'), findsOneWidget);
  });

  testWidgets('empty email shows validation message', (tester) async {
    await pumpLogin(tester);
    await login(tester, '', 'Pass@123');
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Invalid email or password'), findsNothing);
  });

  testWidgets('empty password shows validation message', (tester) async {
    await pumpLogin(tester);
    await login(tester, 'yokesh@example.com', '');
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('invalid email format shows validation message', (tester) async {
    await pumpLogin(tester);
    await login(tester, 'not-an-email', 'x');
    expect(find.text('Please enter a valid email'), findsOneWidget);
  });

  testWidgets('show/hide password icon toggles obscureText', (tester) async {
    await pumpLogin(tester);
    TextField field() => tester.widget<TextField>(
      find.descendant(of: passwordField, matching: find.byType(TextField)),
    );

    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(field().obscureText, isFalse);
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(field().obscureText, isTrue);
  });

  testWidgets('Firestore error is shown without crashing', (tester) async {
    await pumpLogin(tester, service: _FailingAuthService(firestore));
    await login(tester, 'yokesh@example.com', 'Pass@123');
    expect(
      find.text('Database error (unavailable). Please try again.'),
      findsOneWidget,
    );
    expect(find.text('User Login'), findsOneWidget);
  });

  testWidgets('logout returns to the login screen', (tester) async {
    await pumpLogin(tester);
    await login(tester, 'yokesh@example.com', 'Pass@123');
    expect(find.text('Welcome, Yokeshwaran'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Logout'));
    await tester.pumpAndSettle();

    expect(find.text('User Login'), findsOneWidget);
    expect(find.text('Welcome, Yokeshwaran'), findsNothing);
    // Fresh screen: fields are empty again.
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: emailField, matching: find.byType(TextField)),
          )
          .controller!
          .text,
      isEmpty,
    );
  });

  test('users collection is only read, never written', () async {
    final before = await firestore.collection('users').get();
    await AuthService(users: firestore.collection('users'))
        .login('yokesh@example.com', 'Pass@123');
    final after = await firestore.collection('users').get();
    expect(after.docs.length, before.docs.length);
    expect(
      after.docs.map((d) => d.data()).toList(),
      before.docs.map((d) => d.data()).toList(),
    );
  });
}
