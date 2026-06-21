import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Uploads images to Cloudinary (free media host) via unsigned upload presets,
/// so the app needs no server and no API secret. Returns the hosted image URL,
/// which we store in Firestore.
///
/// Setup: a Cloudinary account with an *unsigned* upload preset.
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  // From your Cloudinary dashboard. The upload preset must be set to "Unsigned".
  static const String _cloudName = 'dfjabxuq0';
  static const String _uploadPreset = 'dodoo_unsigned';

  final Dio _dio = Dio();

  String get _endpoint =>
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Uploads the file at [localPath] and returns its secure URL.
  /// [folder] groups uploads (e.g. "rider_documents/<uid>"); [publicId] sets a
  /// stable file name so re-uploads overwrite instead of piling up.
  Future<String> uploadFile(
    String localPath, {
    String? folder,
    String? publicId,
  }) async {
    final bytes = await XFile(localPath).readAsBytes();
    return _upload(bytes, folder: folder, publicId: publicId);
  }

  /// Uploads raw [bytes] (used where we already have the image in memory).
  Future<String> uploadBytes(
    List<int> bytes, {
    String? folder,
    String? publicId,
  }) =>
      _upload(bytes, folder: folder, publicId: publicId);

  Future<String> _upload(
    List<int> bytes, {
    String? folder,
    String? publicId,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: 'upload.jpg'),
      'upload_preset': _uploadPreset,
      if (folder != null) 'folder': folder,
      if (publicId != null) 'public_id': publicId,
    });
    final res = await _dio.post<Map<String, dynamic>>(_endpoint, data: form);
    final url = res.data?['secure_url']?.toString();
    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary upload failed: no URL returned');
    }
    return url;
  }
}
