import '../network/api_response.dart';

class AppErrorHandler {
  static const String fallback = 'Something went wrong. Please try again.';

  /// Maps any caught error (ApiException, status code, or raw message) to UI copy.
  static String from(Object? error) {
    if (error == null) return fallback;
    if (error is ApiException) {
      return _resolve(raw: error.message, statusCode: error.statusCode);
    }
    return _resolve(raw: error.toString());
  }

  /// Kept for existing screens that store a code or message string.
  static String getErrorMessage(String? errorCode) {
    return _resolve(raw: errorCode, statusCode: errorCode);
  }

  static String _resolve({String? raw, String? statusCode}) {
    final message = (raw ?? '').trim();
    final code = (statusCode ?? '').trim();
    if (message.isEmpty && code.isEmpty) return fallback;

    final fromCode = _fromCode(code.isNotEmpty ? code : message);
    if (fromCode != null) return fromCode;

    final fromText = _fromText(message);
    if (fromText != null) return fromText;

    if (_isTechnical(message)) return fallback;
    return message;
  }

  static String? _fromCode(String value) {
    switch (value.toLowerCase()) {
      case 'invalid-credential':
      case 'invalid_credentials':
      case 'wrong-password':
        return 'Incorrect email or password. Please try again.';
      case 'user-not-found':
      case 'account-not-found':
        return 'No account found with this email.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
      case '429':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
      case 'network-error':
      case 'connection-error':
      case 'socket-error':
      case 'timeout':
        return 'Unable to connect. Please check your internet connection and try again.';
      case 'server-error':
      case 'internal-server-error':
      case '500':
      case '502':
      case '503':
        return 'Unable to complete the request. Please try again later.';
      case '401':
        return 'Your session has expired. Please login again.';
      case '403':
        return 'You do not have permission to perform this action.';
      case '404':
        return 'The requested resource was not found.';
      case '400':
      case '422':
        return 'Some details are invalid. Please check and try again.';
      default:
        return null;
    }
  }

  static String? _fromText(String value) {
    final lower = value.toLowerCase();

    if (lower.contains('incorrect') && lower.contains('password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (lower.contains('user not found') || lower.contains('no account found')) {
      return 'No account found with this email.';
    }
    if (lower.contains('disabled')) {
      return 'This account has been disabled. Please contact support.';
    }
    if (lower.contains('too many')) {
      return 'Too many attempts. Please try again later.';
    }
    if (lower.contains('session expired') ||
        lower.contains('unauthorized') ||
        lower.contains('please sign in') ||
        lower.contains('please login')) {
      return 'Your session has expired. Please login again.';
    }
    if (lower.contains('permission') || lower.contains('forbidden')) {
      return 'You do not have permission to perform this action.';
    }
    if (lower.contains('not found') || lower.contains('was not found')) {
      return 'The requested resource was not found.';
    }
    if (lower.contains('unable to reach') ||
        lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network') ||
        lower.contains('timed out') ||
        lower.contains('timeout') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('clientexception')) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }
    if (lower.contains('invalid json') ||
        lower.contains('empty response') ||
        lower.contains('unexpected response') ||
        lower.contains('internal server') ||
        lower.contains('server error')) {
      return 'Unable to complete the request. Please try again later.';
    }
    if (lower.contains('download payload was empty')) {
      return 'Unable to download this document. Please try again.';
    }
    if (lower.contains('request failed')) {
      return fallback;
    }
    return null;
  }

  static bool _isTechnical(String value) {
    final lower = value.toLowerCase();
    return lower.contains('exception') ||
        lower.contains('stack trace') ||
        lower.contains('api_base') ||
        lower.contains('http://') ||
        lower.contains('https://') ||
        lower.contains('statuscode') ||
        value.contains('\n') ||
        value.length > 180;
  }
}
