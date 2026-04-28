/// DTO for group-related API endpoints.
///
/// Handles parsing of group data from different backend families:
/// - Common/OneHub: `{ desc, ratio }` format (from user groups endpoint)
/// - Sub2API: `{ id, name, description, rate_multiplier }` format
///
/// Normalizes all formats to a simple `{ name, description, ratio }` structure.
library;

/// A single group from the groups endpoint.
///
/// Groups are normalized to a simple structure for UI consumption.
/// The [name] is the group identifier used in token operations.
class GroupDto {
  /// Group identifier (used in create/update token requests).
  final String name;

  /// Human-readable description (optional).
  final String? description;

  /// Group ID (Sub2API specific, used for group_id mapping).
  final String? id;

  /// Group ratio / rate multiplier (optional, null when not provided by backend).
  ///
  /// Represents the pricing multiplier for this group. Lower values mean
  /// cheaper usage. Not all endpoints return ratio data (e.g. site groups).
  final double? ratio;

  const GroupDto({required this.name, this.description, this.id, this.ratio});

  /// Parses a raw JSON map from Common/OneHub user groups endpoint.
  ///
  /// Common endpoint: `GET /api/user/self/groups` returns
  /// `Record<string, {desc, ratio}>` — key is the group name.
  static GroupDto fromCommonUserGroup(
    String groupName,
    Map<String, dynamic> json,
  ) {
    return GroupDto(
      name: groupName,
      description: json['desc'] as String?,
      ratio: (json['ratio'] as num?)?.toDouble(),
    );
  }

  /// Parses a raw JSON string from Common site groups endpoint.
  ///
  /// Common endpoint: `GET /api/group` returns `string[]`.
  static GroupDto fromCommonSiteGroup(String groupName) {
    return GroupDto(name: groupName);
  }

  /// Parses a raw JSON map from OneHub user group map endpoint.
  ///
  /// OneHub endpoint: `GET /api/user_group_map` returns
  /// `Record<string, OneHubUserGroupInfo>` — key is the group symbol.
  static GroupDto fromOneHubUserGroup(
    String groupName,
    Map<String, dynamic> json,
  ) {
    return GroupDto(
      name: json['symbol'] as String? ?? groupName,
      description: json['name'] as String?,
      ratio: (json['ratio'] as num?)?.toDouble(),
    );
  }

  /// Parses a raw JSON map from Sub2API groups endpoint.
  ///
  /// Sub2API endpoint: `GET /api/v1/groups/available` returns
  /// `Sub2ApiGroupData[]` with `{ id, name, description, rate_multiplier }`.
  ///
  /// [ratio] is optional because the final ratio may be merged from a separate
  /// `/api/v1/groups/rates` endpoint by the caller before being passed in.
  static GroupDto fromSub2ApiGroup(Map<String, dynamic> json, {double? ratio}) {
    return GroupDto(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      ratio: ratio ?? (json['rate_multiplier'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      'GroupDto(name: $name, description: $description, id: $id, ratio: $ratio)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroupDto && name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Paginated or list response for groups.
///
/// Groups are typically returned as arrays without pagination metadata.
class GroupListDto {
  final List<GroupDto> groups;

  const GroupListDto({required this.groups});

  /// Parses a list of [GroupDto] from various API response formats.
  static GroupListDto fromList(List<GroupDto> groups) {
    return GroupListDto(groups: groups);
  }
}
