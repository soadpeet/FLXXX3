package de.biggo.flxxx3;

import android.content.Intent;
import android.net.Uri;
import androidx.core.content.FileProvider;
import java.io.File;
import java.util.ArrayList;
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

    // ADVANCED SETTINGS > INFO > SHARE LOG: offers the log files to other apps (mail,
    // messenger, cloud) with the Android share menu. The files lie in the app's folder on the
    // shared storage; the FileProvider of Qt (authority <package>.qtprovider) grants access.
    public static void shareFiles(final String[] paths, final String subject) {
        final MainActivity activity = sInstance;
        if (activity == null || paths == null || paths.length == 0) {
            return;
        }
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    ArrayList<Uri> uris = new ArrayList<>();
                    String authority = activity.getPackageName() + ".qtprovider";
                    for (String path : paths) {
                        uris.add(FileProvider.getUriForFile(activity, authority, new File(path)));
                    }
                    Intent send = new Intent(uris.size() == 1 ? Intent.ACTION_SEND
                                                              : Intent.ACTION_SEND_MULTIPLE);
                    send.setType("text/plain");
                    send.putExtra(Intent.EXTRA_SUBJECT, subject);
                    if (uris.size() == 1) {
                        send.putExtra(Intent.EXTRA_STREAM, uris.get(0));
                    } else {
                        send.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris);
                    }
                    send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    activity.startActivity(Intent.createChooser(send, subject));
                } catch (Exception e) {
                    android.util.Log.w("mixxx-qml", "share failed: " + e);
                }
            }
        });
    }

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
        // Set here, before anything is drawn (before, the QML set them when its main window was
        // ready, about 6 s after the start: every change of the window attributes laid out the
        // window again while Qt was drawing, which crashed the app in the system graphics
        // (libgui / RenderThread), mostly at the first start after an installation):
        // the screen stays on while the app is in front, and a fixed refresh rate (the adaptive
        // refresh of some phones makes a still picture flicker when the rate changes).
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        lp.preferredRefreshRate = 60.0f;
        getWindow().setAttributes(lp);
        // IMMERSIVE_STICKY | HIDE_NAVIGATION | FULLSCREEN | LAYOUT_*
        getWindow().getDecorView().setSystemUiVisibility(0x1706);

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
