import 'package:flutter/services.dart';

class SoundService {
  static Future<void> playDeal() => SystemSound.play(SystemSoundType.click);
  static Future<void> playBet() => SystemSound.play(SystemSoundType.click);
  static Future<void> playWin() => SystemSound.play(SystemSoundType.alert);
  static Future<void> playLose() => SystemSound.play(SystemSoundType.alert);
}
