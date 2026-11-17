import 'package:flutter/foundation.dart';

@immutable
class FlashOfferState {
  const FlashOfferState({
    required this.isActive,
    required this.remainingSeconds,
    required this.standardPriceNtd,
    required this.flashPriceNtd,
  });
  final bool isActive;
  final int remainingSeconds;
  final int standardPriceNtd;
  final int flashPriceNtd;
  int get activePriceNtd => isActive ? flashPriceNtd : standardPriceNtd;
}

@immutable
class VernaFlashOfferEngine {
  const VernaFlashOfferEngine._();
  static const int flashWindowDurationSeconds = 900;
  static const int defaultStandardPriceNtd = 590;
  static const int defaultFlashPriceNtd = 390;

  static FlashOfferState evaluateWindow({
    required DateTime triggeredAtUtc,
    required DateTime nowUtc,
  }) {
    final int rawElapsed = nowUtc.toUtc().difference(triggeredAtUtc.toUtc()).inSeconds;
    final int elapsed = rawElapsed < 0 ? 0 : rawElapsed;
    final int rem = (flashWindowDurationSeconds - elapsed).clamp(0, flashWindowDurationSeconds);
    return FlashOfferState(
      isActive: rem > 0,
      remainingSeconds: rem,
      standardPriceNtd: defaultStandardPriceNtd,
      flashPriceNtd: defaultFlashPriceNtd,
    );
  }

  static String formatMmSs(int remainingSeconds) {
    final int safe = remainingSeconds.clamp(0, flashWindowDurationSeconds);
    final String mm = (safe ~/ 60).toString().padLeft(2, '0');
    final String ss = (safe % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  static String buildFlashOfferPitch(FlashOfferState state, {required bool isZh}) {
    if (!state.isActive) {
      return isZh
          ? '⚡ 解鎖個人終身買斷版（NT\$${state.standardPriceNtd} 一次付費永久使用）'
          : r'⚡ Unlock Personal Lifetime ($19.99 One-Time)';
    }
    final String timer = formatMmSs(state.remainingSeconds);
    return isZh
        ? '⏳ 限時閃購倒數 $timer！原價 NT\$${state.standardPriceNtd} ➔ 早鳥特惠 NT\$${state.flashPriceNtd}'
        : '⏳ Flash Offer ends in $timer! Lock Lifetime at \$12.99 today';
  }
}
