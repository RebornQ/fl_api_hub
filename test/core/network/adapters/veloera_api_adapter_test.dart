/// Unit tests for [VeloeraApiAdapter].
///
/// Verifies that Veloera's daily check-in is dispatched to the snake-case
/// path `/api/user/check_in` (not `/api/user/checkin`) and that the request
/// context (auth token, base url, userId) is forwarded via
/// [RequestOptions.extra] so the [AuthInterceptor] can inject the proper
/// authentication headers.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_all_api_hub/core/network/api_request.dart';
import 'package:fl_all_api_hub/core/network/adapters/veloera_api_adapter.dart';
import 'package:fl_all_api_hub/core/network/dio_client.dart';
import 'package:fl_all_api_hub/core/network/site_type.dart';
import 'package:fl_all_api_hub/core/result/result.dart';

// ── Test doubles ────────────────────────────────────────────────────

class _MockDio extends Mock implements Dio {}

/// [DioClient] stand-in that hands back a pre-configured mock [Dio].
///
/// The production [DioClient] constructor installs a real [AuthInterceptor]
/// and owns the [Dio] instance via a `late final` field, which we can't
/// swap at test time. This fake just bypasses that setup.
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
  late VeloeraApiAdapter adapter;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = _MockDio();
    fakeClient = _FakeDioClient(mockDio);
    adapter = VeloeraApiAdapter(fakeClient);
  });

  group('VeloeraApiAdapter', () {
    test('reports siteType as veloera', () {
      expect(adapter.siteType, SiteType.veloera);
    });

    test('checkIn posts to /api/user/check_in with snake_case path', () async {
      // Arrange — Dio returns a success envelope.
      when(
        () => mockDio.request(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/user/check_in'),
          statusCode: 200,
          data: const {
            'success': true,
            'message': '签到成功',
            'data': {'checkin_date': '2026-04-23', 'quota_awarded': 1000},
          },
        ),
      );

      // Act
      final result = await adapter.checkIn(
        const ApiRequest(
          baseUrl: 'https://veloera.example.com',
          authToken: 'tok-veloera',
          authType: AuthType.accessToken,
          userId: 42,
        ),
      );

      // Assert — returned DTO.
      expect(result, isA<Success>());
      final dto = (result as Success).data;
      expect(dto.success, true);
      expect(dto.message, '签到成功');
      expect(dto.data, isNotNull);
      expect(dto.data!.checkinDate, '2026-04-23');
      expect(dto.data!.quotaAwarded, 1000);

      // Assert — call details captured.
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

      expect(
        capturedPath,
        '/api/user/check_in',
        reason: 'Veloera must use the underscore variant',
      );
      expect(capturedPath, isNot(contains('checkin')));
      expect(capturedOptions.method, 'POST');
      expect(
        capturedOptions.extra,
        containsPair('apiBaseUrl', 'https://veloera.example.com'),
      );
      expect(
        capturedOptions.extra,
        containsPair('apiAuthToken', 'tok-veloera'),
      );
      expect(capturedOptions.extra, containsPair('apiAuthType', 'accessToken'));
      expect(
        capturedOptions.extra,
        containsPair('apiUserId', 42),
        reason:
            'userId must be forwarded so AuthInterceptor can add '
            'New-API-User header',
      );
    });

    test('checkIn passes null userId through when account lacks one', () async {
      when(
        () => mockDio.request(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/user/check_in'),
          statusCode: 200,
          data: const {
            'success': true,
            'message': '签到成功',
            'data': {'checkin_date': '2026-04-23', 'quota_awarded': 100},
          },
        ),
      );

      await adapter.checkIn(
        const ApiRequest(
          baseUrl: 'https://veloera.example.com',
          authToken: 'tok-veloera',
          authType: AuthType.accessToken,
          // userId intentionally omitted (defaults to null in the ApiRequest).
        ),
      );

      final captured = verify(
        () => mockDio.request(
          any(),
          options: captureAny(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).captured;
      final capturedOptions = captured[0] as Options;

      expect(capturedOptions.extra, containsPair('apiUserId', null));
    });
  });
}
