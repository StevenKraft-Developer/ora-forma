class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final bool onboardingComplete;
  final List<String> groupIds;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.onboardingComplete,
    required this.groupIds,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      onboardingComplete: map['onboardingComplete'] ?? false,
      groupIds: List<String>.from(map['groupIds'] ?? const []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'onboardingComplete': onboardingComplete,
      'groupIds': groupIds,
    };
  }

  UserProfile copyWith({
    String? displayName,
    bool? onboardingComplete,
    List<String>? groupIds,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      groupIds: groupIds ?? this.groupIds,
    );
  }
}