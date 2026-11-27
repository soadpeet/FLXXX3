// AI disclaimer: this file was written autonomously by an AI agent (Claude).
package de.biggo.flxxx3;

import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbManager;
import android.os.SystemClock;
import android.util.Log;

import java.util.HashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

// Opens the audio device of the controller (DDJ-FLX4, DDJ-FLX10) for the native USB audio driver
// (libusb): asks for the USB permission if necessary and returns the file
// descriptor of the opened device. The connection stays open until close().
public class UsbAudioHelper {
    private static final String TAG = "MixxxUsbAudio";
    private static final String ACTION = "de.biggo.flxxx3.permissions.USB_AUDIO";
    private static UsbDeviceConnection sConnection;
    private static volatile boolean sGranted;
    private static CountDownLatch sLatch;
    // The driver tries to open the device again every 300 ms while it is not connected. Asking
    // for the USB permission each time opened the system dialog again at once (after the screen
    // was off the permission is often gone), so that it could neither be answered nor the app
    // closed. After a request the next one waits (denied: 5 minutes, no answer: 1 minute).
    private static long sNextRequestMs = 0;

    // names: the product names it looks for, separated by "|" (the first one found is opened).
    public static synchronized int openDevice(Context context, String names) {
        close();
        UsbManager manager = (UsbManager) context.getSystemService(Context.USB_SERVICE);
        HashMap<String, UsbDevice> devices = manager.getDeviceList();
        UsbDevice found = null;
        for (UsbDevice device : devices.values()) {
            String product = device.getProductName();
            if (product == null) {
                continue;
            }
            for (String name : names.split("\\|")) {
                if (!name.isEmpty() && product.contains(name)) {
                    found = device;
                    break;
                }
            }
            if (found != null) {
                break;
            }
        }
        if (found == null) {
            Log.w(TAG, "device not found: " + names);
            return -1;
        }
        if (!manager.hasPermission(found)) {
            if (SystemClock.elapsedRealtime() < sNextRequestMs) {
                return -2;
            }
            sNextRequestMs = SystemClock.elapsedRealtime() + 60000;
            sLatch = new CountDownLatch(1);
            sGranted = false;
            BroadcastReceiver receiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context c, Intent intent) {
                    sGranted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false);
                    sLatch.countDown();
                }
            };
            context.registerReceiver(receiver, new IntentFilter(ACTION), Context.RECEIVER_NOT_EXPORTED);
            Intent intent = new Intent(ACTION);
            intent.setPackage(context.getPackageName());
            PendingIntent pending = PendingIntent.getBroadcast(
                    context, 0, intent, PendingIntent.FLAG_MUTABLE);
            manager.requestPermission(found, pending);
            try {
                sLatch.await(30, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                // fall through
            }
            context.unregisterReceiver(receiver);
            if (!sGranted) {
                Log.w(TAG, "USB permission denied");
                if (sLatch.getCount() == 0) {
                    // answered with "cancel": do not ask again for a while
                    sNextRequestMs = SystemClock.elapsedRealtime() + 300000;
                }
                return -2;
            }
            sNextRequestMs = 0;
        }
        sConnection = manager.openDevice(found);
        if (sConnection == null) {
            Log.w(TAG, "openDevice failed");
            return -3;
        }
        return sConnection.getFileDescriptor();
    }

    public static synchronized void close() {
        if (sConnection != null) {
            sConnection.close();
            sConnection = null;
        }
    }
}
