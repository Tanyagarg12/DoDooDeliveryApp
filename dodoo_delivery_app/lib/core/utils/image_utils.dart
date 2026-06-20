import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

class ImageUtils {
  ImageUtils._();

  static final _picker = ImagePicker();

  /// Pick an image from gallery or camera, compress it, and return the File.
  static Future<File?> pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: AppConstants.imageMaxWidth.toDouble(),
        maxHeight: AppConstants.imageMaxHeight.toDouble(),
      );
      if (picked == null) return null;
      return _compress(File(picked.path));
    } catch (e) {
      debugPrint('ImageUtils.pickImage error: $e');
      return null;
    }
  }

  /// Compress a file to under [AppConstants.imageMaxSizeKb] KB.
  static Future<File?> _compress(File file) async {
    try {
      final dir = await getTemporaryDirectory();
      final fileName = 'compressed_${file.uri.pathSegments.last}';
      final targetPath = '${dir.path}/$fileName';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: AppConstants.imageQuality,
        minWidth: AppConstants.imageMaxWidth,
        minHeight: AppConstants.imageMaxHeight,
      );

      if (result == null) return file; // fallback to original
      return File(result.path);
    } catch (e) {
      debugPrint('ImageUtils._compress error: $e');
      return file;
    }
  }

  /// Returns file size in KB.
  static double fileSizeKb(File file) => file.lengthSync() / 1024;
}
