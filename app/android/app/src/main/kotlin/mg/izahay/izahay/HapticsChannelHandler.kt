package mg.izahay.izahay

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Pont entre le MethodChannel Flutter "mg.izahay.izahay/haptics" et l'API
 * de vibration d'Android.
 *
 * Expose trois méthodes au canal :
 * - "hasVibrator" : indique si l'appareil a un vibreur.
 * - "vibrate" : déclenche un motif décrit par l'argument "timings", un
 *   tableau alterné [délai, vibre, pause, vibre, pause, ...] en millisecondes.
 * - "cancel" : arrête toute vibration en cours.
 */
class HapticsChannelHandler(context: Context) : MethodChannel.MethodCallHandler {

    private val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val manager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
        manager.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasVibrator" -> result.success(vibrator.hasVibrator())
            "vibrate" -> {
                val timings = call.argument<List<Int>>("timings")
                if (timings == null) {
                    result.error(
                        "INVALID_ARGUMENT",
                        "L'argument \"timings\" est requis pour \"vibrate\"",
                        null,
                    )
                    return
                }
                vibrate(timings.map { it.toLong() }.toLongArray())
                result.success(null)
            }
            "cancel" -> {
                vibrator.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun vibrate(timings: LongArray) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // -1 : pas de répétition, le motif est joué une seule fois.
            vibrator.vibrate(VibrationEffect.createWaveform(timings, -1))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(timings, -1)
        }
    }
}
