class SettingsOption {
  final String id;
  final String label;
  final bool initialValue;

  const SettingsOption({
    required this.id,
    required this.label,
    this.initialValue = false,
  });
}

class SettingsCategory {
  final String title;
  final List<SettingsOption> options;

  const SettingsCategory({required this.title, required this.options});
}
