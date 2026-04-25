import 'package:dio/dio.dart';

class Task {
  final int id;
  final int parentId;
  final String name;
  final int order;

  Task({required this.id, required this.parentId, required this.name, required this.order});

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['indicator_to_mo_id'] as int,
      parentId: json['parent_id'] as int,
      name: json['name'] as String,
      order: json['order'] as int,
    );
  }

  Task copyWith({int? parentId, int? order}) {
    return Task(
      id: id,
      parentId: parentId ?? this.parentId,
      name: name,
      order: order ?? this.order,
    );
  }

  Task editName({String? name}) {
    return Task(
      id: id,
      parentId: parentId,
      name: name ?? this.name,
      order: order,
    );
  }

  @override
  String toString() {
    return 'Задание: name $name, id $id, parentId $parentId, order $order';
  }
}

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.dev.kpi-drive.ru/_api/indicators/',
    headers: {
      'Authorization': 'Bearer 5c3964b8e3ee4755f2cc0febb851e2f8', 
    },
  ));

  Future<List<Task>> fetchTasks() async {
    final formData = FormData.fromMap({
      'period_start': '2026-04-01', 
      'period_end': '2026-04-30', 
      'period_key': 'month', 
      'requested_mo_id': '42', 
      'behaviour_key': 'task,kpi_task', 
      'with_result': 'false', 
      'response_fields': 'name,indicator_to_mo_id,parent_id,order', 
      'auth_user_id': '40', 
    });

    try {
      final response = await _dio.post('get_mo_indicators', data: formData); 
      final List<dynamic> data = response.data['DATA']['rows'] ?? []; 
      return data.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка загрузки: $e');
      return [];
    }
  }

  Future<bool> saveTaskField(int taskId, String fieldName, dynamic fieldValue) async {
    final formData = FormData.fromMap({
      'period_start': '2026-04-01', 
      'period_end': '2026-04-30', 
      'period_key': 'month', 
      'indicator_to_mo_id': taskId.toString(), 
      'field_name': fieldName, 
      'field_value': fieldValue.toString(), 
      'auth_user_id': '40', 
    });

    try {
      await _dio.post('save_indicator_instance_field', data: formData); 
      return true;
    } catch (e) {
      print('Ошибка сохранения: $e');
      return false;
    }
  }
  Future<bool> deleteTask(int taskId) async {
    final formData = FormData.fromMap({
      'period_start': '2026-04-01',
      'period_end': '2026-04-30',
      'period_key': 'month',
      'indicator_to_mo_id': taskId.toString(),
      'auth_user_id': '40',
    });
    try {
      await _dio.post('delete_indicator_instance', data: formData);
      return true;
    } catch (e) {
      print('Ошибка удаления: $e');
      return false;
    }
  }
}