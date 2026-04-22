/// Unit tests for [CommonApiAdapter.checkIn].
///
/// Verifies that the check-in method ignores apiResponse.success and always
/// returns Success when HTTP 200, delegating status determination to the
/// Mapper layer.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:all_api_hub_flutter/core/network/api_request.dart';
import 'package:all_api_hub_flutter/core/network/adapters/common_api_adapter.dart';
import 'package:all_api_hub_flutter/core/network/dio_client.dart';
import 'package:all_api_hub_flutter/core/network/site_type.dart';
import 'package:all_api_hub_flutter/core/result/result.dart';

// ── Test doubles ────────────────────────────────────────────────────

class _MockDio extends Mock implements Dio {}

class _FakeDioClient implements DioClient {
  _FakeDioClient(this._dio);
  final Dio _dio;

  @override
  Dio get dio => _dio;

  @override
  void addInterceptor(Interceptor interceptor) {}

  @override
  int removeInterceptorsOfType<T extends Interceptor>() => 0;
}

// ── Main ───────────────────────────────────────────────────────────

void main() {
  late _MockDio mockDio;
  late _FakeDioClient fakeClient;
  late CommonApiAdapter adapter;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = _MockDio();
    fakeClient = _FakeDioClient(mockDio);
    adapter = CommonApiAdapter(fakeClient);
  });

  group('CommonApiAdapter.checkIn', () {
    test('returns Success when HTTP 200 and success=true', () async {
      when(
        () => mockDio.request(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/user/checkin'),
          statusCode: 200,
          data: const {
            'success': true,
            'message': '签到成功',
            'data': {'checkin_date': '2026-04-23', 'quota_awarded': 1000},
          },
        ),
      );

      final result = await adapter.checkIn(
        const ApiRequest(
          baseUrl: 'https://api.example.com',
          authToken: 'tok-123',
          authType: AuthType.accessToken,
          userId: 42,
        ),
      );

      expect(result, isA<Success>());
      final dto = (result as Success).data;
      expect(dto.success, true);
      expect(dto.message, '签到成功');
      expect(dto.data, isNotNull);
      expect(dto.data!.checkinDate, '2026-04-23');
      expect(dto.data!.quotaAwarded, 1000);
    });

    test(
      'returns Success when HTTP 200 and success=false (already checked)',
      () async {
        when(
          () => mockDio.request(
            any(),
            options: any(named: 'options'),
            queryParameters: any(named: 'queryParameters'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/api/user/checkin'),
            statusCode: 200,
            data: const {'success': false, 'message': '今日已签到'},
          ),
        );

        final result = await adapter.checkIn(
          const ApiRequest(
            baseUrl: 'https://api.example.com',
            authToken: 'tok-123',
            authType: AuthType.accessToken,
            userId: 42,
          ),
        );

        // Should return Success even though success=false
        expect(result, isA<Success>());
        final dto = (result as Success).data;
        expect(dto.success, false);
        expect(dto.message, '今日已签到');
      },
    );

    test(
      'returns Success when HTTP 200 and success=false (other error)',
      () async {
        when(
          () => mockDio.request(
            any(),
            options: any(named: 'options'),
            queryParameters: any(named: 'queryParameters'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            requestOptions: RequestOptions(path: '/api/user/checkin'),
            statusCode: 200,
            data: const {'success': false, 'message': '签到失败,请稍后重试'},
          ),
        );

        final result = await adapter.checkIn(
          const ApiRequest(
            baseUrl: 'https://api.example.com',
            authToken: 'tok-123',
            authType: AuthType.accessToken,
            userId: 42,
          ),
        );

        // Should return Success even for business errors
        expect(result, isA<Success>());
        final dto = (result as Success).data;
        expect(dto.success, false);
        expect(dto.message, '签到失败,请稍后重试');
      },
    );

    test('returns Failure when DioException occurs', () async {
      when(
        () => mockDio.request(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/api/user/checkin'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      final result = await adapter.checkIn(
        const ApiRequest(
          baseUrl: 'https://api.example.com',
          authToken: 'tok-123',
          authType: AuthType.accessToken,
          userId: 42,
        ),
      );

      expect(result, isA<Failure>());
    });

    test('forwards request context via Options.extra', () async {
      when(
        () => mockDio.request(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/user/checkin'),
          statusCode: 200,
          data: const {
            'success': true,
            'message': 'ok',
            'data': {'checkin_date': '2026-04-23', 'quota_awarded': 500},
          },
        ),
      );

      await adapter.checkIn(
        const ApiRequest(
          baseUrl: 'https://api.example.com',
          authToken: 'tok-abc',
          authType: AuthType.accessToken,
          userId: 99,
        ),
      );

      final captured = verify(
        () => mockDio.request(
          captureAny(),
          options: captureAny(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).captured;

      final capturedPath = captured[0] as String;
      final capturedOptions = captured[1] as Options;

      expect(capturedPath, '/api/user/checkin');
      expect(capturedOptions.method, 'POST');
      expect(
        capturedOptions.extra,
        containsPair('apiBaseUrl', 'https://api.example.com'),
      );
      expect(capturedOptions.extra, containsPair('apiAuthToken', 'tok-abc'));
      expect(capturedOptions.extra, containsPair('apiAuthType', 'accessToken'));
      expect(capturedOptions.extra, containsPair('apiUserId', 99));
    });
  });
}
