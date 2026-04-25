class Task {
  final int id;
  final int parentId;
  final String name;
  final int order;

  Task({required this.id, required this.parentId, required this.name, required this.order});

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['indicator_to_mo_id'] as int,
    parentId: json['parent_id'] as int,
    name: json['name'] as String,
    order: json['order'] as int,
  );

  Task copyWith({int? parentId, String? name, int? order}) => Task(
    id: id,
    parentId: parentId ?? this.parentId,
    name: name ?? this.name,
    order: order ?? this.order,
  );

  @override
  String toString() => 'Задание: name $name, id $id, parentId $parentId, order $order';
}