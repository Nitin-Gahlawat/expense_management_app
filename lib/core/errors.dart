import 'package:logger/logger.dart';

abstract class AppException implements Exception {
  final String message;
  final dynamic innerException;
  final StackTrace? stackTrace;

  const AppException(this.message, {this.innerException, this.stackTrace});

  @override
  String toString() => 'AppException: $message';

  void log(Logger logger) {
    logger.e(message, error: innerException, stackTrace: stackTrace);
  }
}

class DatabaseException extends AppException {
  const DatabaseException(
    super.message, {
    super.innerException,
    super.stackTrace,
  });

  @override
  String toString() => 'DatabaseException: $message';

  factory DatabaseException.initializationFailed({
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      'Failed to initialize database',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory DatabaseException.readFailed({
    required String key,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      'Failed to read data for key: $key',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory DatabaseException.writeFailed({
    required String operation,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      'Failed to write data during operation: $operation',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory DatabaseException.deleteFailed({
    required String key,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      'Failed to delete data for key: $key',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory DatabaseException.adapterRegistrationFailed({
    required String typeName,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return DatabaseException(
      'Failed to register adapter for type: $typeName',
      innerException: error,
      stackTrace: stackTrace,
    );
  }
}

class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException(
    super.message, {
    this.statusCode,
    super.innerException,
    super.stackTrace,
  });

  @override
  String toString() =>
      'NetworkException: $message ${statusCode != null ? "(Status: $statusCode)" : ''}';

  factory NetworkException.connectionFailed({
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return NetworkException(
      'Failed to establish network connection',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory NetworkException.timeout({
    Duration? timeout,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return NetworkException(
      'Request timed out${timeout != null ? ' after ${timeout.inSeconds} seconds' : ''}',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory NetworkException.httpError({
    required int statusCode,
    required String reason,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return NetworkException(
      'HTTP error: $statusCode - $reason',
      statusCode: statusCode,
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory NetworkException.invalidApiKey({
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return NetworkException(
      'Invalid or missing API key',
      statusCode: 401,
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory NetworkException.rateLimitExceeded({
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return NetworkException(
      'API rate limit exceeded. Please try again later.',
      statusCode: 429,
      innerException: error,
      stackTrace: stackTrace,
    );
  }
}

class ImageException extends AppException {
  const ImageException(super.message, {super.innerException, super.stackTrace});

  @override
  String toString() => 'ImageException: $message';

  factory ImageException.pickFailed({
    required String source,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ImageException(
      'Unable to select image from $source. Please try again.',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory ImageException.compressionFailed({
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ImageException(
      'Failed to compress image',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory ImageException.fileAccessFailed({
    required String path,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ImageException(
      'Failed to access image file at: $path',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory ImageException.invalidFormat({
    required String format,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ImageException(
      'Invalid or unsupported image format: $format',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory ImageException.sizeLimitExceeded({
    required int maxSizeBytes,
    required int actualSizeBytes,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ImageException(
      'Image size exceeds limit. Maximum: ${maxSizeBytes ~/ (1024 * 1024)}MB, '
      'Actual: ${actualSizeBytes ~/ (1024 * 1024)}MB',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory ImageException.permissionDenied({
    required String permission,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ImageException(
      'Permission denied: $permission',
      innerException: error,
      stackTrace: stackTrace,
    );
  }
}

class AIException extends AppException {
  const AIException(super.message, {super.innerException, super.stackTrace});

  @override
  String toString() => 'AIException: $message';

  factory AIException.modelInitializationFailed({
    required String modelName,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return AIException(
      'Failed to initialize AI model: $modelName',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory AIException.inferenceFailed({
    required String reason,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return AIException(
      'AI inference failed: $reason',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory AIException.responseParsingFailed({
    required String expectedFormat,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return AIException(
      'Failed to parse AI response. Expected format: $expectedFormat',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory AIException.invalidResponseStructure({
    required String missingField,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return AIException(
      'AI response missing required field: $missingField',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory AIException.contentPolicyViolation({
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return AIException(
      'AI request violated content policy',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory AIException.quotaExceeded({dynamic error, StackTrace? stackTrace}) {
    return AIException(
      'AI service quota exceeded',
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory AIException.invalidInput({
    required String reason,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return AIException(
      'Invalid input provided to AI service: $reason',
      innerException: error,
      stackTrace: stackTrace,
    );
  }
}

class ValidationException extends AppException {
  final String? field;

  const ValidationException(
    super.message, {
    this.field,
    super.innerException,
    super.stackTrace,
  });

  @override
  String toString() =>
      'ValidationException${field != null ? ' (field: $field)' : ''}: $message';

  factory ValidationException.requiredField({
    required String fieldName,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ValidationException(
      'Field is required: $fieldName',
      field: fieldName,
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory ValidationException.invalidFormat({
    required String fieldName,
    required String expectedFormat,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ValidationException(
      'Invalid format for $fieldName. Expected: $expectedFormat',
      field: fieldName,
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory ValidationException.outOfRange({
    required String fieldName,
    required String range,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ValidationException(
      'Value out of range for $fieldName. Valid range: $range',
      field: fieldName,
      innerException: error,
      stackTrace: stackTrace,
    );
  }

  factory ValidationException.invalidEnumValue({
    required String fieldName,
    required List<String> validValues,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    return ValidationException(
      'Invalid value for $fieldName. Valid values: ${validValues.join(", ")}',
      field: fieldName,
      innerException: error,
      stackTrace: stackTrace,
    );
  }
}
