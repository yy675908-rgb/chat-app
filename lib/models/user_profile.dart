class UserProfile {
  const UserProfile({
    this.name = '',
    this.gender = '',
    this.description = '',
  });

  final String name;
  final String gender;
  final String description;

  bool get isEmpty =>
      name.trim().isEmpty &&
      gender.trim().isEmpty &&
      description.trim().isEmpty;

  Map<String, Object?> toJson() => {
        'name': name,
        'gender': gender,
        'description': description,
      };

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      name: json['name']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}
