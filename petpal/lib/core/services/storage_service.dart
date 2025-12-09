import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  /// Upload a profile photo for a dog and return the download URL
  Future<String?> uploadDogPhoto(String localPath, {String? dogId}) async {
    if (userId == null) throw Exception('User not logged in');

    final file = File(localPath);
    if (!await file.exists()) {
      print('StorageService: File does not exist at $localPath');
      return null;
    }

    try {
      final fileName = dogId ?? const Uuid().v4();
      final ref = _storage
          .ref()
          .child('users')
          .child(userId!)
          .child('dogs')
          .child('$fileName.jpg');

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('StorageService: Uploaded photo to $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('StorageService: Error uploading photo: $e');
      return null;
    }
  }

  /// Upload a walk moment photo
  Future<String?> uploadWalkPhoto(String localPath, String walkId) async {
    if (userId == null) throw Exception('User not logged in');

    final file = File(localPath);
    if (!await file.exists()) return null;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('users')
          .child(userId!)
          .child('walks')
          .child(walkId)
          .child('$timestamp.jpg');

      final uploadTask = ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('StorageService: Error uploading walk photo: $e');
      return null;
    }
  }

  /// Delete a photo from storage
  Future<void> deletePhoto(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      print('StorageService: Error deleting photo: $e');
    }
  }
}
