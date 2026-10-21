class PickupTypeModel {
  final int id;
  final String title;

  const PickupTypeModel({
    required this.id,
    required this.title,
  });

  factory PickupTypeModel.fromJson(Map<String, dynamic> json) {
    return PickupTypeModel(
      id: json['id_pickup_type'] as int,
      title: json['title'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_pickup_type': id,
      'title': title,
    };
  }
}