import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/rider_entity.dart';
import '../models/rider_model.dart';

class OtpVerifyResult {
  final RiderModel rider;
  final String accessToken;
  final String refreshToken;

  const OtpVerifyResult({
    required this.rider,
    required this.accessToken,
    required this.refreshToken,
  });
}

class AuthRemoteDataSource {
  final ApiClient _client;
  const AuthRemoteDataSource(this._client);

  Future<CheckPhoneResult> checkPhone(String phone) async {
    try {
      final res = await _client.post(ApiConstants.checkPhone, data: {'phone': phone});
      final data = res.data as Map<String, dynamic>;
      return CheckPhoneResult(
        exists: data['exists'] as bool,
        phone: data['phone']?.toString() ?? phone,
        accountStatus: data['exists'] == true
            ? AccountStatus.fromString(data['account_status']?.toString())
            : null,
        riderId: data['rider_id']?.toString(),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<String> sendOtp(String phone) async {
    try {
      final res = await _client.post(ApiConstants.sendOtp, data: {'phone': phone});
      final data = res.data as Map<String, dynamic>;
      return data['dev_otp']?.toString() ?? '';
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<OtpVerifyResult> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final res = await _client.post(
        ApiConstants.verifyOtp,
        data: {'phone': phone, 'otp': otp},
      );
      final data = res.data as Map<String, dynamic>;
      final accessToken =
          data['access_token']?.toString() ?? data['token']?.toString() ?? '';
      final refreshToken = data['refresh_token']?.toString() ?? '';
      final riderJson = data['rider'] as Map<String, dynamic>? ?? {};

      return OtpVerifyResult(
        rider: RiderModel.fromJson(riderJson),
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<void> register(RegistrationData data) async {
    try {
      final fields = <String, dynamic>{
        'phone': data.phone,
        'first_name': data.firstName,
        'last_name': data.lastName,
      };
      if (data.email != null && data.email!.isNotEmpty) {
        fields['email'] = data.email;
      }
      if (data.address != null && data.address!.isNotEmpty) {
        fields['address'] = data.address;
      }
      if (data.aadhaarNumber != null && data.aadhaarNumber!.isNotEmpty) {
        fields['aadhar_number'] = data.aadhaarNumber;
      }
      if (data.drivingLicenseNumber != null &&
          data.drivingLicenseNumber!.isNotEmpty) {
        fields['driving_license_number'] = data.drivingLicenseNumber;
      }
      if (data.profilePicturePath != null) {
        fields['profile_picture'] =
            await _toMultipart(data.profilePicturePath!);
      }
      if (data.aadhaarFrontPath != null) {
        fields['aadhar_front'] = await _toMultipart(data.aadhaarFrontPath!);
      }
      if (data.aadhaarBackPath != null) {
        fields['aadhar_back'] = await _toMultipart(data.aadhaarBackPath!);
      }
      if (data.drivingLicenseImagePath != null) {
        fields['driving_license_image'] =
            await _toMultipart(data.drivingLicenseImagePath!);
      }

      await _client.postMultipart(ApiConstants.register, FormData.fromMap(fields));
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Fetches the current account_status for the authenticated rider.
  /// Uses the JWT token already stored by the interceptor.
  Future<AccountStatus> fetchAccountStatus() async {
    try {
      final res = await _client.get(ApiConstants.meStatus);
      final data = res.data as Map<String, dynamic>;
      return AccountStatus.fromString(data['account_status']?.toString());
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<MultipartFile> _toMultipart(String filePath) async {
    return MultipartFile.fromFile(
      filePath,
      filename: filePath.split(Platform.pathSeparator).last,
    );
  }

  Exception _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == 401) return const UnauthorizedException();

    final body = e.response?.data;
    String message;

    // Django debug page (HTML) — usually means migrations haven't been applied
    if (body is String && body.trimLeft().startsWith('<')) {
      message = statusCode == 500
          ? 'Server error (500) — run "python manage.py migrate" then restart the backend'
          : 'Unexpected server response (HTTP $statusCode)';
    } else if (body is Map) {
      final first = body['error'] ?? body['detail'] ?? body.values.firstOrNull;
      message = first?.toString() ?? 'Unknown error';
    } else {
      message = e.message ?? 'Server error';
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkException();
    }
    return ServerException(message, statusCode: statusCode);
  }
}
