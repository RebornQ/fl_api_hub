import 'package:flutter_test/flutter_test.dart';
import 'package:all_api_hub_flutter/core/network/site_type.dart';

void main() {
  group('SiteType', () {
    test('fromValue returns correct enum for known values', () {
      expect(SiteType.fromValue('new-api'), SiteType.newApi);
      expect(SiteType.fromValue('one-hub'), SiteType.oneHub);
      expect(SiteType.fromValue('Veloera'), SiteType.veloera);
      expect(SiteType.fromValue('sub2api'), SiteType.sub2api);
      expect(SiteType.fromValue('wong-gongyi'), SiteType.wongGongyi);
    });

    test('fromValue throws for unknown value', () {
      expect(() => SiteType.fromValue('unknown-site'), throwsArgumentError);
    });

    test('newApi has accessToken auth type and is managed', () {
      expect(SiteType.newApi.defaultAuthType, AuthType.accessToken);
      expect(SiteType.newApi.isManaged, isTrue);
    });

    test('sub2api has cookie auth type and is not managed', () {
      expect(SiteType.sub2api.defaultAuthType, AuthType.cookie);
      expect(SiteType.sub2api.isManaged, isFalse);
    });

    test('all site types have non-empty value', () {
      for (final site in SiteType.values) {
        expect(site.value, isNotEmpty);
      }
    });
  });
}
