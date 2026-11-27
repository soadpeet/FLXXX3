package de.biggo.flxxx3;

import android.app.Activity;
import android.app.ActivityOptions;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.hardware.display.DisplayManager;
import android.os.Bundle;
import android.view.Display;
import java.util.ArrayList;
import java.util.Collections;

// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// The app icon starts this activity. It starts MainActivity on the monitor chosen in ADVANCED
// SETTINGS > START > SCREEN (1 = the screen of the device, 2 and up = the other screens, e.g. a
// monitor on a DeX cable; a number that is too high means the last one) and ends. Nothing of the
// app runs yet at this point, so nothing has to be restarted (a restart of the running app lost
// the USB audio of the controller).
public class LauncherActivity extends Activity {
    static final String PREFS = "flxxx3_start";
    static final String KEY_MONITOR = "monitor";

    // The setting is kept here for the next start (called by the app, see MainActivity).
    static void saveMonitor(Context context, int index) {
        context.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putInt(KEY_MONITOR, index).apply();
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent main = new Intent(this, MainActivity.class);
        main.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        Bundle options = null;
        try {
            SharedPreferences prefs = getSharedPreferences(PREFS, MODE_PRIVATE);
            int index = prefs.getInt(KEY_MONITOR, 2);
            DisplayManager manager = (DisplayManager) getSystemService(Context.DISPLAY_SERVICE);
            ArrayList<Integer> ids = new ArrayList<>();
            for (Display d : manager.getDisplays()) {
                if (d.getDisplayId() != Display.DEFAULT_DISPLAY) {
                    ids.add(d.getDisplayId());
                }
            }
            Collections.sort(ids);
            ids.add(0, Display.DEFAULT_DISPLAY);
            int target = ids.get(Math.max(1, Math.min(index, ids.size())) - 1);
            int current = getWindowManager().getDefaultDisplay().getDisplayId();
            android.util.Log.i("mixxx-qml", "monitor wanted " + index + " -> display " + target
                    + ", started from " + current);
            if (target != current) {
                options = ActivityOptions.makeBasic().setLaunchDisplayId(target).toBundle();
            }
        } catch (Exception e) {
            android.util.Log.w("mixxx-qml", "monitor choice failed: " + e);
        }
        if (options != null) {
            startActivity(main, options);
        } else {
            startActivity(main);
        }
        finish();
    }
}
