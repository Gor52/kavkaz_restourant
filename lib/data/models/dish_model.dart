class DishModel {
  final int id;
  final int categoryId;
  final String title;
  final String description;
  final String ingredients;
  final double price;
  final int weight;
  final int? calories;
  final String? allergens;
  final String? photoPath;
  final bool isAvailable;
  final DateTime? createdAt;

  const DishModel({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.price,
    required this.weight,
    this.calories,
    this.allergens,
    this.photoPath,
    required this.isAvailable,
    this.createdAt,
  });

  factory DishModel.fromJson(Map<String, dynamic> json) {
    return DishModel(
      id: json['id_dish'] as int,
      categoryId: json['category_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      ingredients: json['ingredients'] as String,
      price: double.parse(json['price'].toString()),
      weight: json['weight'] as int,
      calories: json['calories'] as int?,
      allergens: json['allergens'] as String?,
      photoPath: json['photo_path'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_dish': id,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'price': price,
      'weight': weight,
      'calories': calories,
      'allergens': allergens,
      'photo_path': photoPath,
      'is_available': isAvailable,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}