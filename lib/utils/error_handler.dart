import 'package:flutter/foundation.dart';

/// Utility class for handling and simplifying error messages for users
class ErrorHandler {
  /// Convert technical error messages to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    if (error == null) {
      return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
    }

    final errorString = error.toString().toLowerCase();

    // Network/Connection errors
    if (errorString.contains('connection reset') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out') ||
        errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network is unreachable')) {
      return 'فشل الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
    }

    // Authentication errors
    if (errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('token') ||
        errorString.contains('session')) {
      return 'انتهت صلاحية الجلسة. يرجى تسجيل الدخول مرة أخرى.';
    }

    // Supabase specific errors
    if (errorString.contains('supabase') ||
        errorString.contains('postgres') ||
        errorString.contains('database')) {
      return 'حدث خطأ في قاعدة البيانات. يرجى المحاولة مرة أخرى.';
    }

    // Timeout errors
    if (errorString.contains('timeout') ||
        errorString.contains('timed out')) {
      return 'انتهت مهلة الاتصال. يرجى المحاولة مرة أخرى.';
    }

    // Permission errors
    if (errorString.contains('permission') ||
        errorString.contains('forbidden') ||
        errorString.contains('access denied')) {
      return 'ليس لديك صلاحية للوصول إلى هذا المحتوى.';
    }

    // Not found errors
    if (errorString.contains('not found') ||
        errorString.contains('404')) {
      return 'المحتوى المطلوب غير موجود.';
    }

    // Server errors
    if (errorString.contains('500') ||
        errorString.contains('internal server error') ||
        errorString.contains('server error')) {
      return 'حدث خطأ في الخادم. يرجى المحاولة لاحقاً.';
    }

    // Validation errors
    if (errorString.contains('validation') ||
        errorString.contains('invalid') ||
        errorString.contains('required')) {
      return 'البيانات المدخلة غير صحيحة. يرجى التحقق من المعلومات.';
    }

    // Generic error
    return 'حدث خطأ غير متوقع. يرجى المحاولة مرة أخرى.';
  }

  /// Get error type for logging purposes
  static String getErrorType(dynamic error) {
    if (error == null) return 'Unknown';

    final errorString = error.toString().toLowerCase();

    if (errorString.contains('connection') || errorString.contains('socket')) {
      return 'NetworkError';
    }
    if (errorString.contains('auth') || errorString.contains('token')) {
      return 'AuthError';
    }
    if (errorString.contains('timeout')) {
      return 'TimeoutError';
    }
    if (errorString.contains('permission') || errorString.contains('forbidden')) {
      return 'PermissionError';
    }
    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'NotFoundError';
    }
    if (errorString.contains('500') || errorString.contains('server error')) {
      return 'ServerError';
    }
    if (errorString.contains('validation') || errorString.contains('invalid')) {
      return 'ValidationError';
    }

    return 'UnknownError';
  }

  /// Log error with full details (for debugging)
  static void logError(dynamic error, {String? context, StackTrace? stackTrace}) {
    final errorType = getErrorType(error);
    final userMessage = getUserFriendlyMessage(error);
    
    debugPrint('❌ [$errorType] ${context ?? "Error"}:');
    debugPrint('   User Message: $userMessage');
    debugPrint('   Technical Details: $error');
    if (stackTrace != null) {
      debugPrint('   Stack Trace: $stackTrace');
    }
  }
}

/// Utility class for automatic retry with exponential backoff
class RetryHandler {
  /// Execute a function with automatic retry
  /// 
  /// [function] - The async function to execute
  /// [maxRetries] - Maximum number of retry attempts (default: 3)
  /// [initialDelay] - Initial delay before first retry in seconds (default: 1)
  /// [maxDelay] - Maximum delay between retries in seconds (default: 10)
  /// [onRetry] - Callback called before each retry attempt
  static Future<T> executeWithRetry<T>({
    required Future<T> Function() function,
    int maxRetries = 3,
    int initialDelay = 1,
    int maxDelay = 10,
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    int attempt = 0;
    
    while (attempt <= maxRetries) {
      try {
        return await function();
      } catch (error) {
        attempt++;
        
        // Don't retry on the last attempt
        if (attempt > maxRetries) {
          rethrow;
        }

        // Calculate delay with exponential backoff
        final delaySeconds = (initialDelay * (1 << (attempt - 1))).clamp(1, maxDelay);
        final delay = Duration(seconds: delaySeconds);

        // Log retry attempt
        final errorType = ErrorHandler.getErrorType(error);
        debugPrint('⚠️ Retry attempt $attempt/$maxRetries after ${delaySeconds}s (Error: $errorType)');

        // Call onRetry callback if provided
        if (onRetry != null) {
          onRetry(attempt, delay);
        }

        // Wait before retrying
        await Future.delayed(delay);
      }
    }

    // This should never be reached, but just in case
    throw Exception('Retry failed after $maxRetries attempts');
  }

  /// Check if error is retryable
  static bool isRetryable(dynamic error) {
    if (error == null) return false;

    final errorString = error.toString().toLowerCase();

    // Retryable errors
    if (errorString.contains('connection reset') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out') ||
        errorString.contains('socketexception') ||
        errorString.contains('timeout') ||
        errorString.contains('network') ||
        errorString.contains('500') ||
        errorString.contains('503') ||
        errorString.contains('502')) {
      return true;
    }

    // Non-retryable errors
    if (errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('404') ||
        errorString.contains('validation') ||
        errorString.contains('invalid')) {
      return false;
    }

    // Default to retryable for unknown errors
    return true;
  }
}

