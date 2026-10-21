class RoleModel {
  final int id;
  final String title;

  const RoleModel({
    required this.id,
    required this.title,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: json['id_role'] as int,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_role': id,
      'title': title,
    };
  }
}