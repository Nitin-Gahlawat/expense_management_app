import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import '../core/errors.dart';

class ImagePickResult {
  final File imageFile;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int originalWidth;
  final int originalHeight;
  final int compressedWidth;
  final int compressedHeight;
  final String mimeType;

  const ImagePickResult({
    required this.imageFile,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.compressedWidth,
    required this.compressedHeight,
    required this.mimeType,
  });

  double get compressionRatio =>
      compressedSizeBytes > 0 ? originalSizeBytes / compressedSizeBytes : 1.0;

  double get sizeReductionPercentage => originalSizeBytes > 0
      ? ((originalSizeBytes - compressedSizeBytes) / originalSizeBytes) * 100
      : 0.0;

  @override
  String toString() {
    return 'ImagePickResult(file: ${imageFile.path}, '
        'original: ${originalSizeBytes ~/ 1024}KB, '
        'compressed: ${compressedSizeBytes ~/ 1024}KB, '
        'ratio: ${compressionRatio.toStringAsFixed(2)}x)';
  }
}

class ImageCompressionConfig {
  final int maxWidth;

  final int maxHeight;

  final int quality;

  final int maxFileSizeBytes;

  const ImageCompressionConfig({
    this.maxWidth = 1920,
    this.maxHeight = 1080,
    this.quality = 85,
    this.maxFileSizeBytes = 2 * 1024 * 1024, // 2MB
  });

  static const receiptScanning = ImageCompressionConfig(
    maxWidth: 1280,
    maxHeight: 720,
    quality: 80,
    maxFileSizeBytes: 1024 * 1024, // 1MB
  );

  static const highQuality = ImageCompressionConfig(
    maxWidth: 2048,
    maxHeight: 1536,
    quality: 90,
    maxFileSizeBytes: 3 * 1024 * 1024, // 3MB
  );

  static const lowQuality = ImageCompressionConfig(
    maxWidth: 800,
    maxHeight: 600,
    quality: 70,
    maxFileSizeBytes: 512 * 1024, // 512KB
  );
}

class ImageService {
  final ImagePicker _picker;
  final Logger logger;

  Directory? _tempDir;

  ImageService({ImagePicker? picker, Logger? logger})
    : _picker = picker ?? ImagePicker(),
      logger = logger ?? Logger();

  Future<void> initialize() async {
    try {
      logger.i('Initializing ImageService');
      _tempDir = await getTemporaryDirectory();
      logger.i(
        'ImageService initialized with temp directory: ${_tempDir!.path}',
      );
    } catch (e, stackTrace) {
      logger.e(
        'Failed to initialize ImageService',
        error: e,
        stackTrace: stackTrace,
      );
      throw ImageException.fileAccessFailed(
        path: 'temporary directory',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ImagePickResult> pickImage(
    ImageSource source, {
    ImageCompressionConfig config = ImageCompressionConfig.receiptScanning,
  }) async {
    try {
      logger.i('Picking image from source: $source');

      if (_tempDir == null) {
        await initialize();
      }

      // Pick the image
      final xFile = await _pickImageFromSource(source);

      logger.d('Image picked: ${xFile.path}, size: ${xFile.length()} bytes');

      // Read the original image
      final originalFile = File(xFile.path);
      final originalBytes = await originalFile.readAsBytes();

      // Decode image to get dimensions
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        throw ImageException.invalidFormat(
          format: 'Unable to decode image',
          error: 'Image decoder returned null',
        );
      }

      final originalWidth = originalImage.width;
      final originalHeight = originalImage.height;

      logger.d('Original image dimensions: ${originalWidth}x${originalHeight}');

      // Compress the image
      final compressedResult = await _compressImage(
        originalImage,
        config: config,
        originalPath: xFile.path,
      );

      logger.i('Image compression complete: $compressedResult');

      return compressedResult;
    } on ImageException {
      rethrow;
    } catch (e, stackTrace) {
      logger.e(
        'Unexpected error during image pick',
        error: e,
        stackTrace: stackTrace,
      );
      throw ImageException.pickFailed(
        source: source.name,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<XFile> _pickImageFromSource(ImageSource source) async {
    try {
      final imageSource = source == ImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery;

      final xFile = await _picker.pickImage(
        source: imageSource,
        imageQuality: 100, // Get highest quality first, we'll compress later
        preferredCameraDevice: CameraDevice.rear,
      );

      if (xFile == null) {
        throw ImageException.pickFailed(
          source: source.name,
          error: 'User cancelled image selection',
        );
      }

      return xFile;
    } on ImageException {
      rethrow;
    } catch (e, stackTrace) {
      if (e.toString().contains('Permission')) {
        throw ImageException.permissionDenied(
          permission: source == ImageSource.camera ? 'Camera' : 'Gallery',
          error: e,
          stackTrace: stackTrace,
        );
      }
      throw ImageException.pickFailed(
        source: source.name,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<ImagePickResult> _compressImage(
    img.Image originalImage, {
    required ImageCompressionConfig config,
    required String originalPath,
  }) async {
    try {
      logger.d(
        'Starting image compression with config: ${config.maxWidth}x${config.maxHeight}, quality: ${config.quality}',
      );

      // Calculate new dimensions maintaining aspect ratio
      final newDimensions = _calculateNewDimensions(
        originalImage.width,
        originalImage.height,
        maxWidth: config.maxWidth,
        maxHeight: config.maxHeight,
      );

      logger.d(
        'New dimensions: ${newDimensions.width}x${newDimensions.height}',
      );

      // Resize the image
      img.Image resizedImage;
      if (newDimensions.width != originalImage.width ||
          newDimensions.height != originalImage.height) {
        resizedImage = img.copyResize(
          originalImage,
          width: newDimensions.width,
          height: newDimensions.height,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resizedImage = originalImage;
      }

      // Encode to JPEG with specified quality
      final compressedBytes = Uint8List.fromList(
        img.encodeJpg(resizedImage, quality: config.quality),
      );

      logger.d('Compressed size: ${compressedBytes.length} bytes');

      // Check if size is still too large, reduce quality if needed
      Uint8List finalBytes = compressedBytes;

      if (compressedBytes.length > config.maxFileSizeBytes) {
        logger.d('Compressed size exceeds limit, reducing quality');

        // Iteratively reduce quality until size is acceptable or quality is too low
        for (int q = config.quality - 10; q >= 50; q -= 10) {
          final testBytes = Uint8List.fromList(
            img.encodeJpg(resizedImage, quality: q),
          );

          if (testBytes.length <= config.maxFileSizeBytes) {
            finalBytes = testBytes;
            logger.d('Final quality: $q, size: ${testBytes.length} bytes');
            break;
          }
        }

        // If still too large, reduce dimensions
        if (finalBytes.length > config.maxFileSizeBytes) {
          logger.d('Still too large, reducing dimensions');

          for (int scale = 2; scale <= 4; scale++) {
            final scaledWidth = (newDimensions.width / scale).round();
            final scaledHeight = (newDimensions.height / scale).round();

            final scaledImage = img.copyResize(
              resizedImage,
              width: scaledWidth,
              height: scaledHeight,
              interpolation: img.Interpolation.linear,
            );

            final testBytes = Uint8List.fromList(
              img.encodeJpg(scaledImage, quality: 70),
            );

            if (testBytes.length <= config.maxFileSizeBytes) {
              finalBytes = testBytes;
              logger.d(
                'Final scale: ${scale}x, size: ${testBytes.length} bytes',
              );
              break;
            }
          }
        }
      }

      // Save compressed image to temp file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedPath = '${_tempDir!.path}/compressed_$timestamp.jpg';
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(finalBytes);

      logger.d('Compressed image saved to: $compressedPath');

      // Get original file size
      final originalFile = File(originalPath);
      final originalSizeBytes = await originalFile.length();

      // Create result
      final result = ImagePickResult(
        imageFile: compressedFile,
        originalSizeBytes: originalSizeBytes,
        compressedSizeBytes: finalBytes.length,
        originalWidth: originalImage.width,
        originalHeight: originalImage.height,
        compressedWidth: resizedImage.width,
        compressedHeight: resizedImage.height,
        mimeType: 'image/jpeg',
      );

      logger.i(
        'Compression complete: ${result.compressionRatio.toStringAsFixed(2)}x reduction',
      );

      return result;
    } catch (e, stackTrace) {
      logger.e('Image compression failed', error: e, stackTrace: stackTrace);
      throw ImageException.compressionFailed(error: e, stackTrace: stackTrace);
    }
  }

  _Dimensions _calculateNewDimensions(
    int originalWidth,
    int originalHeight, {
    required int maxWidth,
    required int maxHeight,
  }) {
    if (originalWidth <= maxWidth && originalHeight <= maxHeight) {
      return _Dimensions(originalWidth, originalHeight);
    }

    final widthRatio = maxWidth / originalWidth;
    final heightRatio = maxHeight / originalHeight;
    final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

    return _Dimensions(
      (originalWidth * ratio).round(),
      (originalHeight * ratio).round(),
    );
  }

  Future<void> cleanup() async {
    try {
      if (_tempDir != null && await _tempDir!.exists()) {
        logger.i('Cleaning up temporary files in ${_tempDir!.path}');

        final files = _tempDir!.listSync();
        for (final file in files) {
          if (file is File) {
            await file.delete();
            logger.d('Deleted temporary file: ${file.path}');
          }
        }
      }
    } catch (e, stackTrace) {
      logger.e('Error during cleanup', error: e, stackTrace: stackTrace);
      // Don't throw, cleanup errors shouldn't break the app
    }
  }

  Future<bool> isValidImage(File file) async {
    try {
      if (!await file.exists()) {
        return false;
      }

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      return image != null;
    } catch (e) {
      logger.e('Image validation failed', error: e);
      return false;
    }
  }

  Future<Map<String, dynamic>> getImageInfo(File file) async {
    try {
      if (!await file.exists()) {
        throw ImageException.fileAccessFailed(path: file.path);
      }

      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw ImageException.invalidFormat(format: 'Unknown');
      }

      return {
        'width': image.width,
        'height': image.height,
        'sizeBytes': bytes.length,
        'sizeKB': bytes.length / 1024,
        'sizeMB': bytes.length / (1024 * 1024),
        'hasAlphaChannel': image.numChannels == 4,
      };
    } catch (e, stackTrace) {
      logger.e('Failed to get image info', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  void dispose() {
    logger.i('Disposing ImageService');
    cleanup();
  }
}

class _Dimensions {
  final int width;
  final int height;

  const _Dimensions(this.width, this.height);
}
