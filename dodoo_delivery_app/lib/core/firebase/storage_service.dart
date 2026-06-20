import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Thin wrapper around Firebase Storage for the rider app's image uploads
/// (profile photos + KYC documents).
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final _storage = FirebaseStorage.instance;

  /// Uploads the local file at [localPath] to [storagePath] (e.g.
  /// "rider_documents/<uid>/aadhar_front.jpg") and returns its download URL.
  /// Reads via [XFile] so it works on both mobile and web.
  Future<String> uploadFile(String storagePath, String localPath) async {
    final bytes = await XFile(localPath).readAsBytes();
    final ref = _storage.ref(storagePath);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
