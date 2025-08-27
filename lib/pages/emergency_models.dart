// lib/models/emergency_models.dart
class EmergencyContact {
  final int id;               // contact row id
  final int targetUserId;     // 친구 user_id
  final String? relation;
  final bool isEmergency;     // 항상 true (레코드 존재)
  final String? targetUsername;
  final String? targetProfileImageURL;

  EmergencyContact({
    required this.id,
    required this.targetUserId,
    required this.relation,
    required this.isEmergency,
    required this.targetUsername,
    required this.targetProfileImageURL,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> j) {
    return EmergencyContact(
      id: j['id'] as int,
      targetUserId: j['target_user_id'] as int,
      relation: j['relation'] as String?,
      isEmergency: (j['is_emergency'] as bool?) ?? true,
      targetUsername: j['target_username'] as String?,
      targetProfileImageURL: j['target_profile_imageURL'] as String?,
    );
  }
}

class EmergencyBroadcastCreate {
  final String message;
  final bool includeLocation;
  final double? lat;
  final double? lon;
  final String? address;            // 선택
  final List<int>? contactIds;      // 선택(없으면 전체)

  EmergencyBroadcastCreate({
    required this.message,
    required this.includeLocation,
    this.lat,
    this.lon,
    this.address,
    this.contactIds,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'message': message,
      'include_location': includeLocation,
    };
    if (includeLocation) {
      if (lat != null) m['lat'] = lat;
      if (lon != null) m['lon'] = lon;
      if (address != null && address!.isNotEmpty) m['address'] = address;
    }
    if (contactIds != null && contactIds!.isNotEmpty) {
      m['contact_ids'] = contactIds;
    }
    return m;
  }
}
