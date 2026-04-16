import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class InstallationService {
  InstallationService({required SharedPreferences preferences})
    : _preferences = preferences;

  static const _installationIdKey = 'installation_id';

  final SharedPreferences _preferences;
  final Uuid _uuid = const Uuid();

  Future<String> getInstallationId() async {
    final existing = _preferences.getString(_installationIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final id = _uuid.v4();
    await _preferences.setString(_installationIdKey, id);
    return id;
  }
}
