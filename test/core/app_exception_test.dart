import 'package:flutter_test/flutter_test.dart';
import 'package:twitter_clone/core/exceptions/app_exception.dart';

void main() {
  group('AppException', () {
    test('AuthException stores message', () {
      const e = AuthException('Invalid email');
      expect(e.message, 'Invalid email');
      expect(e.toString(), 'Invalid email');
    });

    test('DatabaseException stores message', () {
      const e = DatabaseException('Connection failed');
      expect(e.message, 'Connection failed');
      expect(e.toString(), 'Connection failed');
    });

    test('StorageException stores message', () {
      const e = StorageException('Upload failed');
      expect(e.message, 'Upload failed');
    });

    test('NetworkException stores message', () {
      const e = NetworkException('No internet');
      expect(e.message, 'No internet');
    });

    test('subclasses are instances of AppException', () {
      const auth = AuthException('test');
      const db = DatabaseException('test');
      const storage = StorageException('test');
      const network = NetworkException('test');

      expect(auth, isA<AppException>());
      expect(db, isA<AppException>());
      expect(storage, isA<AppException>());
      expect(network, isA<AppException>());
    });

    test('can be used in switch exhaustiveness', () {
      AppException e = const AuthException('test');
      final result = switch (e) {
        AuthException() => 'auth',
        DatabaseException() => 'db',
        StorageException() => 'storage',
        NetworkException() => 'network',
      };
      expect(result, 'auth');
    });
  });
}
