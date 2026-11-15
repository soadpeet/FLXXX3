package de.biggo.flxxx3;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import android.os.Process;

// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// Runs in an own process (see the manifest), starts the app again and ends the old process:
// the app then starts with the controller that was plugged in after the first start.
public class RestartActivity extends Activity {
    static final String EXTRA_MAIN_INTENT = "main_intent";
    static final String EXTRA_PID = "pid";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Intent mainIntent = getIntent().getParcelableExtra(EXTRA_MAIN_INTENT);
        int pid = getIntent().getIntExtra(EXTRA_PID, -1);
        if (mainIntent != null) {
            startActivity(mainIntent);
        }
        if (pid > 0) {
            Process.killProcess(pid);
        }
        finish();
        Runtime.getRuntime().exit(0);
    }
}
