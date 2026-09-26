class SoundRule {
  final String category;
  final List<String> yamnetClasses;
  final double threshold;
  final double alpha;
  final int vibrationPriority;

  const SoundRule({
    required this.category,
    required this.yamnetClasses,
    this.threshold = 0.30,
    this.alpha = 0.4,
    required this.vibrationPriority,
  });
}

class SoundPriorityConfig {
  static const List<SoundRule> rules = [
    // --- Priorite vibration 5 ---
    SoundRule(
      category: 'train',
      yamnetClasses: ['Train', 'Train horn', 'Train whistle'],
      vibrationPriority: 5,
    ),
    SoundRule(
      category: 'fire_alarm',
      yamnetClasses: ['Fire alarm'],
      vibrationPriority: 5,
    ),
    SoundRule(
      category: 'smoke_alarm',
      yamnetClasses: ['Smoke detector, smoke alarm'],
      vibrationPriority: 5,
    ),

    // --- Priorite vibration 4 ---
    SoundRule(
      category: 'car_horn',
      yamnetClasses: [
        'Vehicle horn, car horn, honking',
        'Toot',
        'Air horn, truck horn',
      ],
      vibrationPriority: 4,
    ),
    SoundRule(
      category: 'emergency_siren',
      yamnetClasses: [
        'Siren',
        'Civil defense siren',
        'Police car (siren)',
        'Ambulance (siren)',
        'Fire engine, fire truck (siren)',
        'Emergency vehicle',
      ],
      vibrationPriority: 4,
    ),
    SoundRule(
      category: 'car_alarm',
      yamnetClasses: ['Car alarm'],
      vibrationPriority: 4,
    ),

    // --- Priorite vibration 3 ---
    SoundRule(
      category: 'baby_cry',
      yamnetClasses: ['Baby cry, infant cry', 'Crying, sobbing'],
      vibrationPriority: 3,
    ),
    SoundRule(
      category: 'alarm',
      yamnetClasses: ['Alarm', 'Buzzer'],
      vibrationPriority: 3,
    ),

    // --- Priorite vibration 2 ---
    SoundRule(
      category: 'doorbell',
      yamnetClasses: ['Doorbell', 'Ding-dong'],
      vibrationPriority: 2,
    ),
    SoundRule(
      category: 'door_knock',
      yamnetClasses: ['Knock'],
      vibrationPriority: 2,
    ),
    SoundRule(
      category: 'telephone',
      yamnetClasses: ['Telephone', 'Telephone bell ringing', 'Ringtone'],
      vibrationPriority: 2,
    ),
    SoundRule(
      category: 'alarm_clock',
      yamnetClasses: ['Alarm clock'],
      vibrationPriority: 2,
    ),

    // --- Priorite vibration 1 ---
    SoundRule(
      category: 'dog_bark',
      yamnetClasses: ['Bark', 'Yip', 'Bow-wow'],
      vibrationPriority: 1,
    ),
  ];
}
