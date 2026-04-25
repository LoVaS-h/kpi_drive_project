import 'package:dio/dio.dart';

import 'task_model.dart';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.dev.kpi-drive.ru/_api/indicators/',
    headers: {
      'Authorization': 'Bearer 5c3964b8e3ee4755f2cc0febb851e2f8',
    },
  ));
  
  Map<String, dynamic> get _baseParams => {
    'period_start': '2026-04-01',
    'period_end': '2026-04-30',
    'period_key': 'month',
    'auth_user_id': '40',
  };

  Future<List<Task>> fetchTasks() async {
    try {
      final response = await _dio.post('get_mo_indicators', data: FormData.fromMap({
        ..._baseParams,
        'requested_mo_id': '42',
        'behaviour_key': 'task,kpi_task',
        'with_result': 'false',
        'response_fields': 'name,indicator_to_mo_id,parent_id,order',
      }));
      final List<dynamic> data = response.data['DATA']['rows'] ?? [];
      return data.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      print('Ошибка загрузки: $e');
      return [];
    }
  }

  Future<bool> saveTaskField(int taskId, String fieldName, dynamic fieldValue) async {
    try {
      await _dio.post('save_indicator_instance_field', data: FormData.fromMap({
        ..._baseParams,
        'indicator_to_mo_id': taskId.toString(),
        'field_name': fieldName,
        'field_value': fieldValue.toString(),
      }));
      return true;
    } catch (e) {
      print('Ошибка сохранения: $e');
      return false;
    }
  }

  Future<bool> deleteTask(int taskId) async {
    try {
      await _dio.post('delete_indicator_instance', data: FormData.fromMap({
        ..._baseParams,
        'indicator_to_mo_id': taskId.toString(),
      }));
      return true;
    } catch (e) {
      print('Ошибка удаления: $e');
      return false;
    }
  }
}