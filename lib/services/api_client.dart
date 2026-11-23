import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.detail});
  final String message;
  final int? statusCode;
  final String? detail; // رسالة السيرفر الأصلية (للتشخيص)
  @override
  String toString() => message;
}

/// Dio جاهز بثلاث Interceptors: إعادة محاولة، تسجيل (بدون بيانات حساسة)، وتحويل الأخطاء لرسائل عربي.
class ApiClient {
  ApiClient._();

  static Dio create({required String baseUrl, Map<String, String>? headers, bool log = kDebugMode}) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      headers: headers,
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 45),
    ));
    dio.interceptors.addAll([
      RetryInterceptor(dio),
      if (log) _LogInterceptor(),
      _ErrorInterceptor(),
    ]);
    return dio;
  }

  static String messageOf(Object e) {
    if (e is ApiException) return e.message;
    if (e is DioException && e.error is ApiException) return (e.error as ApiException).message;
    return 'حصل خطأ غير متوقع';
  }

  /// نفس الرسالة + تفاصيل السيرفر (لو موجودة) عشان نعرف السبب الحقيقي.
  static String describe(Object e) {
    final ex = e is DioException && e.error is ApiException ? e.error as ApiException : (e is ApiException ? e : null);
    if (ex == null) return messageOf(e);
    final d = ex.detail;
    final code = ex.statusCode != null ? ' [${ex.statusCode}]' : '';
    return d == null || d.isEmpty ? '${ex.message}$code' : '${ex.message}$code\n$d';
  }
}

/// بيعيد المحاولة مرتين لو الشبكة وقعت أو السيرفر رجّع ٥xx / ٤٢٩.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {this.maxRetries = 2});
  final Dio _dio;
  final int maxRetries;

  bool _retryable(DioException e) {
    final s = e.response?.statusCode;
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout ||
        (s != null && s >= 500);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final attempt = (err.requestOptions.extra['attempt'] as int?) ?? 0;
    if (!_retryable(err) || attempt >= maxRetries) return handler.next(err);
    await Future<void>.delayed(Duration(milliseconds: 600 * (attempt + 1)));
    try {
      final opts = err.requestOptions..extra['attempt'] = attempt + 1;
      handler.resolve(await _dio.fetch<dynamic>(opts));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// بيسجّل الطلب والرد فقط (من غير headers عشان المفتاح ما يظهرش).
class _LogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    debugPrint('→ ${o.method} ${o.uri.replace(query: '')}');
    h.next(o);
  }

  @override
  void onResponse(Response<dynamic> r, ResponseInterceptorHandler h) {
    debugPrint('← ${r.statusCode} ${r.requestOptions.path}');
    h.next(r);
  }

  @override
  void onError(DioException e, ErrorInterceptorHandler h) {
    debugPrint('✗ ${e.response?.statusCode ?? e.type.name} ${e.requestOptions.path}');
    h.next(e);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final s = err.response?.statusCode;
    final msg = switch (err.type) {
      DioExceptionType.connectionTimeout || DioExceptionType.sendTimeout || DioExceptionType.receiveTimeout => 'الاتصال بطيء، جرّب تاني',
      DioExceptionType.connectionError => 'مفيش اتصال بالإنترنت',
      _ => switch (s) {
          400 => 'الطلب مش مفهوم للسيرفر',
          401 || 403 => 'مش مسموح — راجع مفتاح الخدمة',
          429 => 'طلبات كتير، استنى شوية وجرّب',
          final c? when c >= 500 => 'السيرفر مشغول، جرّب بعد شوية',
          404 => 'الخدمة أو الموديل مش موجود',
          _ => 'تعذر الاتصال بالخدمة',
        },
    };
    String? detail;
    final data = err.response?.data;
    if (data is Map && data['error'] is Map) {
      detail = '${(data['error'] as Map)['message'] ?? ''}';
    } else if (err.type == DioExceptionType.unknown || err.type == DioExceptionType.badCertificate) {
      detail = '${err.error ?? err.type.name}';
    }
    if (detail != null && detail.length > 180) detail = '${detail.substring(0, 180)}…';
    handler.next(err.copyWith(error: ApiException(msg, statusCode: s, detail: detail)));
  }
}
