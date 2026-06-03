// lib/services/api/contact_service.dart
// 紧急联系人 API（v2.0 — Phase 2 双写同步）

import '../api_service.dart';

class ContactService {
  /// 获取紧急联系人列表（从后端拉取）
  static Future<Map<String, dynamic>> getContacts() async {
    return await ApiService.get('/api/contacts');
  }

  /// 批量保存联系人（老用户首次迁移用）
  static Future<Map<String, dynamic>> saveContacts(
      List<Map<String, dynamic>> contacts) async {
    return await ApiService.post('/api/contacts/batch', body: {'contacts': contacts});
  }

  /// 添加联系人
  static Future<Map<String, dynamic>> addContact(
      Map<String, dynamic> contact) async {
    return await ApiService.post('/api/contacts', body: contact);
  }

  /// 编辑联系人
  static Future<Map<String, dynamic>> updateContact(
      String contactId, Map<String, dynamic> data) async {
    return await ApiService.put('/api/contacts/$contactId', body: data);
  }

  /// 重新排序联系人
  static Future<Map<String, dynamic>> reorderContacts(
      List<int> contactIds) async {
    return await ApiService.put('/api/contacts/reorder', body: {'contact_ids': contactIds});
  }

  /// 删除联系人
  static Future<Map<String, dynamic>> deleteContact(String contactId) async {
    return await ApiService.delete('/api/contacts/$contactId');
  }
}
