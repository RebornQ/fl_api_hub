/// Unit tests for [CommonApiAdapter].
///
/// Covers check-in, token CRUD (listTokens, createToken, updateToken,
/// deleteToken), and response envelope handling including edge cases like
/// direct array format and null data success responses.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_api_hub/core/network/api_request.dart';
import 'package:fl_api_hub/core/network/adapters/common_api_adapter.dart';
import 'package:fl_api_hub/core/network/dio_client.dart';
import 'package:fl_api_hub/core/network/dto/token_dto.dart';
import 'package:fl_api_hub/core/network/proxy_config.dart';
import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/core/result/result.dart';

const _testRequest = ApiRequest(
  baseUrl: 'https://api.example.com',
  authToken: 'tok-123',
  authType: AuthType.accessToken,
  userId: 42,
);

// ── Test doubles ────────────────────────────────────────────────────

class _MockDio extends Mock implements Dio {}

class _FakeDioClient implements DioClient {
  _FakeDioClient(this._dio);
  final Dio _dio;

  @override
  Dio getDio({ProxyConfig? proxy}) => _dio;

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

  // ── listTokens ──────────────────────────────────────────────────

  group('CommonApiAdapter.listTokens', () {
    test('returns Success for paginated format (Format B)', () async {
      when(
        () => mockDio.request(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/token/'),
          statusCode: 200,
          data: const {
            'success': true,
            'message': '',
            'data': {
              'items': [
                {'id': 1, 'name': 'token-a'},
                {'id': 2, 'name': 'token-b'},
              ],
              'total': 2,
            },
          },
        ),
      );

      final result = await adapter.listTokens(_testRequest);
      expect(result, isA<Success<TokenListDto>>());
      final list = (result as Success<TokenListDto>).data;
      expect(list.tokens, hasLength(2));
      expect(list.total, 2);
    });

    test('returns Success for direct array format (Format A)', () async {
      when(
        () => mockDio.request(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/token/'),
          statusCode: 200,
          data: const {
            'success': true,
            'message': '',
            'data': [
              {'id': 1, 'name': 'token-a'},
            ],
          },
        ),
      );

      final result = await adapter.listTokens(_testRequest);
      expect(result, isA<Success<TokenListDto>>());
      final list = (result as Success<TokenListDto>).data;
      expect(list.tokens, hasLength(1));
      expect(list.tokens[0].name, 'token-a');
    });

    test('returns Failure when success=false', () async {
      when(
        () => mockDio.request(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/token/'),
          statusCode: 200,
          data: const {
            'success': false,
            'message': 'Unauthorized',
            'data': null,
          },
        ),
      );

      final result = await adapter.listTokens(_testRequest);
      expect(result, isA<Failure<TokenListDto>>());
    });
  });

  // ── createToken ──────────────────────────────────────────────────

  group('CommonApiAdapter.createToken', () {
    test(
      'returns Success when data is null (standard create response)',
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
            requestOptions: RequestOptions(path: '/api/token/'),
            statusCode: 200,
            data: const {'success': true, 'message': '', 'data': null},
          ),
        );

        final result = await adapter.createToken(
          _testRequest,
          name: 'test-token',
        );
        expect(result, isA<Success<TokenDto>>());
      },
    );

    test('returns Failure when success=false', () async {
      when(
        () => mockDio.request(
          any(),
          options: any(named: 'options'),
          queryParameters: any(named: 'queryParameters'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/token/'),
          statusCode: 200,
          data: const {'success': false, 'message': '令牌名称已存在', 'data': null},
        ),
      );

      final result = await adapter.createToken(_testRequest, name: 'duplicate');
      expect(result, isA<Failure<TokenDto>>());
    });
  });

  // ── updateToken ──────────────────────────────────────────────────

  group('CommonApiAdapter.updateToken', () {
    test(
      'returns Success when data is null (standard update response)',
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
            requestOptions: RequestOptions(path: '/api/token/'),
            statusCode: 200,
            data: const {'success': true, 'message': '', 'data': null},
          ),
        );

        final result = await adapter.updateToken(
          _testRequest,
          tokenId: '1',
          name: 'updated',
        );
        expect(result, isA<Success<TokenDto>>());
      },
    );
  });

  // ── deleteToken ──────────────────────────────────────────────────

  group('CommonApiAdapter.deleteToken', () {
    test('returns Success when envelope says success', () async {
      when(
        () => mockDio.delete(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/token/1'),
          statusCode: 200,
          data: const {'success': true, 'message': '', 'data': null},
        ),
      );

      final result = await adapter.deleteToken(_testRequest, tokenId: '1');
      expect(result, isA<Success<void>>());
    });

    test('returns Failure when envelope says success=false', () async {
      when(
        () => mockDio.delete(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/token/1'),
          statusCode: 200,
          data: const {'success': false, 'message': '删除令牌失败', 'data': null},
        ),
      );

      final result = await adapter.deleteToken(_testRequest, tokenId: '1');
      expect(result, isA<Failure<void>>());
    });
  });
}
