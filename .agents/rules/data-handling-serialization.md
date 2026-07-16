# Data Handling & Serialization

- **JSON Serialization:** Use the `json_serializable` package (with `json_annotation`) to generate code for encoding/decoding JSON data into Dart objects.
- **Field Naming:** Use the `@JsonSerializable(fieldRename: FieldRename.snake)` annotation to automatically convert Dart field names from camelCase to snake_case in JSON. For example:

  ```dart
  import 'package:json_annotation/json_annotation.dart';
  part 'user.g.dart';

  @JsonSerializable(fieldRename: FieldRename.snake)
  class User {
    final String firstName;
    final String lastName;

    User({required this.firstName, required this.lastName});

    factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
    Map<String, dynamic> toJson() => _$UserToJson(this);
  }
  ```
