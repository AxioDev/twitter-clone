import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twitter_clone/features/auth/providers/auth_provider.dart';
import 'package:twitter_clone/features/auth/screens/sign_in_screen.dart';

import '../helpers/mocks.dart';
import '../helpers/test_data.dart';

void main() {
  late MockAuthRepository mockAuthRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository();
  });

  group('SignInScreen', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text("Don't have an account? Sign Up"), findsOneWidget);
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('calls signIn with correct credentials', (tester) async {
      when(() => mockAuthRepo.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => testUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      verify(() => mockAuthRepo.signIn(
            email: 'test@test.com',
            password: 'password123',
          )).called(1);
    });

    testWidgets('shows error message on sign in failure', (tester) async {
      when(() => mockAuthRepo.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Invalid credentials'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockAuthRepo),
          ],
          child: const MaterialApp(home: SignInScreen()),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'test@test.com');
      await tester.enterText(find.byType(TextFormField).last, 'wrongpw');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid credentials'), findsOneWidget);
    });
  });
}
