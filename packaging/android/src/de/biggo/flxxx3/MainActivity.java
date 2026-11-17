package de.biggo.flxxx3;

import android.content.Intent;
import android.os.Build;
import android.os.Bundle;
import android.view.WindowInsets;
import android.view.WindowManager;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import org.qtproject.qt.android.QtActivityBase;

public class MainActivity extends QtActivityBase {
    private static MainActivity sInstance;

    // Starts the app again in a new process (called from native code when the controller was
    // plugged in after the start and the sound could not go to it).
    public static void restartApp() {
        final MainActivity activity = sInstance;
        if (activity == null) {
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Intent mainIntent = activity.getPackageManager()
                        .getLaunchIntentForPackage(activity.getPackageName());
                if (mainIntent == null) {
                    return;
                }
                mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
                Intent restart = new Intent(activity, RestartActivity.class);
                restart.putExtra(RestartActivity.EXTRA_MAIN_INTENT, mainIntent);
                restart.putExtra(RestartActivity.EXTRA_PID, android.os.Process.myPid());
                activity.startActivity(restart);
            }
        });
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        sInstance = this;

        // Disable drawing over cutout - isn't working
        WindowManager.LayoutParams lp = this.getWindow().getAttributes();
        lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_NEVER;

        // Disable system and navigation bar to prevent accidental back or app switch
        WindowInsetsControllerCompat windowInsetsController =
            WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        windowInsetsController.setSystemBarsBehavior(
            WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        windowInsetsController.hide(WindowInsetsCompat.Type.navigationBars());

        // Qt makes the window full screen a few seconds after the start and hides the system
        // overlays then (QtDisplayManager.setSystemUiVisibility). That changed the insets once
        // more while Qt was already drawing: the relayout of the surface at that moment crashed
        // the app now and then in the system graphics (libgui, release callback of the buffer
        // queue), mostly at the first start after an installation. Hiding them here already makes
        // Qt's later call a no-op, so the surface is not laid out again.
        if (Build.VERSION.SDK_INT >= 34) {
            getWindow().getInsetsController().hide(WindowInsets.Type.systemOverlays());
        }
    }
}
