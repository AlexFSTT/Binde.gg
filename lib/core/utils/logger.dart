import 'dart:developer' as dev;

/// Simple logger wrapper.
class Log {
  Log._();

  static void d(String message, {String tag = 'BINDE'}) {
    dev.log('[$tag] $message');
  }

  static void e(String message, {Object? error, StackTrace? stack, String tag = 'BINDE'}) {
    dev.log('[$tag] ERROR: $message', error: error, stackTrace: stack);
  }

  static void w(String message, {String tag = 'BINDE'}) {
    dev.log('[$tag] WARN: $message');
  }
}
