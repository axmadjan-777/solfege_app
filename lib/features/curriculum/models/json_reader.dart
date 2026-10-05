/// Ошибка разбора контента: путь до поля помогает быстро найти место в JSON.
class CurriculumFormatException implements Exception {
  CurriculumFormatException(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => 'CurriculumFormatException($path): $message';
}

/// Типизированное чтение полей из декодированного JSON с понятными ошибками.
class JsonReader {
  JsonReader(this.json, this.path);

  factory JsonReader.of(Object? value, String path) {
    if (value is! Map<String, dynamic>) {
      throw CurriculumFormatException(path, 'ожидался объект, получено $value');
    }
    return JsonReader(value, path);
  }

  final Map<String, dynamic> json;
  final String path;

  bool has(String key) => json.containsKey(key) && json[key] != null;

  T _require<T>(String key) {
    final value = json[key];
    if (value is T) return value;
    throw CurriculumFormatException(
      '$path.$key',
      value == null ? 'обязательное поле отсутствует' : 'ожидался $T, получено ${value.runtimeType}',
    );
  }

  String string(String key) => _require<String>(key);

  String? optString(String key) => has(key) ? string(key) : null;

  int integer(String key) => _require<num>(key).toInt();

  int? optInt(String key) => has(key) ? integer(key) : null;

  double number(String key) => _require<num>(key).toDouble();

  double? optNumber(String key) => has(key) ? number(key) : null;

  bool boolean(String key) => _require<bool>(key);

  bool? optBool(String key) => has(key) ? boolean(key) : null;

  List<dynamic> list(String key) => _require<List<dynamic>>(key);

  List<dynamic> optList(String key) => has(key) ? list(key) : const [];

  List<String> strings(String key) => _strings(key, list(key));

  List<String> optStrings(String key) => has(key) ? strings(key) : const [];

  List<int> optInts(String key) {
    if (!has(key)) return const [];
    final values = list(key);
    return [
      for (var i = 0; i < values.length; i++)
        if (values[i] is num)
          (values[i] as num).toInt()
        else
          throw CurriculumFormatException('$path.$key[$i]', 'ожидалось число'),
    ];
  }

  JsonReader object(String key) => JsonReader.of(json[key], '$path.$key');

  JsonReader? optObject(String key) => has(key) ? object(key) : null;

  List<JsonReader> objects(String key) {
    final values = list(key);
    return [
      for (var i = 0; i < values.length; i++) JsonReader.of(values[i], '$path.$key[$i]'),
    ];
  }

  List<String> _strings(String key, List<dynamic> values) {
    return [
      for (var i = 0; i < values.length; i++)
        if (values[i] is String)
          values[i] as String
        else
          throw CurriculumFormatException('$path.$key[$i]', 'ожидалась строка'),
    ];
  }
}
