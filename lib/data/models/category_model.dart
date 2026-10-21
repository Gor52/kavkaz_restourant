class CategoryModel {
  final int id;
  final String title;
  final int sortOrder;

  const CategoryModel({
    required this.id,
    required this.title,
    required this.sortOrder,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id_category'] as int,
      title: json['title'] as String,
      sortOrder: json['sort_order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_category': id,
      'title': title,
      'sort_order': sortOrder,
    };
  }
}