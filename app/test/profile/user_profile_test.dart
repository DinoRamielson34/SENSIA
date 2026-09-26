import 'package:flutter_test/flutter_test.dart';
import 'package:izahay/models/color_vision_type.dart';
import 'package:izahay/models/user_profile.dart';
import 'package:izahay/models/user_role.dart';
import 'package:izahay/models/vibration_segment.dart';

void main() {
  test('toMap puis fromMap redonne le même profil', () {
    final profile = UserProfile(
      role: UserRole.client,
      colorVision: ColorVisionType.tritanopie,
      settings: {'cat1_param1': true, 'cat1_param2': false},
      vibrationPatterns: {
        'baby_cry': [VibrationSegment.long, VibrationSegment.short],
      },
    );

    final copy = UserProfile.fromMap(profile.toMap());

    expect(copy.role, UserRole.client);
    expect(copy.colorVision, ColorVisionType.tritanopie);
    expect(copy.settings, {'cat1_param1': true, 'cat1_param2': false});
    expect(copy.vibrationPatterns['baby_cry'], [
      VibrationSegment.long,
      VibrationSegment.short,
    ]);
  });

  test('un profil vide et des valeurs inconnues ne font pas échouer', () {
    final copy = UserProfile.fromMap({
      'role': 'inconnu',
      'vibrationPatterns': {
        'x': ['long', 'martien'],
      },
    });

    expect(copy.role, isNull);
    expect(copy.colorVision, isNull);
    expect(copy.settings, isEmpty);
    expect(copy.vibrationPatterns['x'], [VibrationSegment.long]);
  });
}
