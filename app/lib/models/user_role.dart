import '../localization/app_strings.dart';

enum UserRole {
  accompagnateur,
  client;

  String label(AppStrings strings) => switch (this) {
    UserRole.accompagnateur => strings.roleAccompagnateur,
    UserRole.client => strings.roleClient,
  };
}
