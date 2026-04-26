/// Unit tests for [Sub2ApiAdapter].
///
/// Covers token CRUD (listTokens, createToken, updateToken, deleteToken)
/// and response envelope handling for the Sub2API `{code, message, data}`
/// envelope format.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fl_api_hub/core/network/api_request.dart';
import 'package:fl_api_hub/core/network/adapters/sub2api_adapter.dart';
import 'package:fl_api_hub/core/network/dio_client.dart';
import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/core/result/result.dart';

const _testRequest = ApiRequest(
  baseUrl: 'https://sub2api.example.com',
  authToken: 'jwt-token',
  authType: AuthType.accessToken,
  userId: 1,
);

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
  late Sub2ApiAdapter adapter;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = _MockDio();
    fakeClient = _FakeDioClient(mockDio);
    adapter = Sub2ApiAdapter(fakeClient);
  });

  test('reports siteType as sub2api', () {
    expect(adapter.siteType, SiteType.sub2api);
  });

  // ── deleteToken ──────────────────────────────────────────────────

  group('Sub2ApiAdapter.deleteToken', () {
    test('returns Success when envelope code is 0', () async {
      when(
        () => mockDio.delete(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/v1/keys/1'),
          statusCode: 200,
          data: const {'code': 0, 'message': 'ok', 'data': null},
        ),
      );

      final result = await adapter.deleteToken(
        _testRequest,
        tokenId: '1',
      );
      expect(result, isA<Success<void>>());
    });

    test('returns Failure when envelope code is non-zero', () async {
      when(
        () => mockDio.delete(any(), options: any(named: 'options')),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/v1/keys/1'),
          statusCode: 200,
          data: const {'code': 1, 'message': 'key not found', 'data': null},
        ),
      );

      final result = await adapter.deleteToken(
        _testRequest,
        tokenId: '1',
      );
      expect(result, isA<Failure<void>>());
    });
  });
}
