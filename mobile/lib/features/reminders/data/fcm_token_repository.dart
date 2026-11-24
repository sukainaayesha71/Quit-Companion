import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class FcmTokenRepository {
  Future<void> saveToken(
    String userId,
    String token, {
    List<String> notificationTypes = const ['daily_checkin'],
  });

  Future<void> deleteToken(String userId, String token);
}

class FirestoreFcmTokenRepository implements FcmTokenRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreFcmTokenRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _tokensFor(String userId) =>
      _firestore
          .collection('nicotineUsers')
          .doc(userId)
          .collection('fcmTokens');

  static String documentIdForToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();

  @override
  Future<void> saveToken(
    String userId,
    String token, {
    List<String> notificationTypes = const ['daily_checkin'],
  }) async {
    if (_auth.currentUser?.uid != userId || token.isEmpty) return;
    await _tokensFor(userId).doc(documentIdForToken(token)).set({
      'token': token,
      'notificationTypes': notificationTypes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteToken(String userId, String token) async {
    if (_auth.currentUser?.uid != userId || token.isEmpty) return;
    await _tokensFor(userId).doc(documentIdForToken(token)).delete();
  }
}
