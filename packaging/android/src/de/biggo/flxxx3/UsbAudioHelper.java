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
import android.util.Log;

import java.util.HashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

// Opens the audio device of the DDJ-FLX4 for the native USB audio driver
// (libusb): asks for the USB permission if necessary and returns the file
// descriptor of the opened device. The connection stays open until close().
public class UsbAudioHelper {
    private static final String TAG = "MixxxUsbAudio";
    private static final String ACTION = "de.biggo.flxxx3.permissions.USB_AUDIO";
    private static UsbDeviceConnection sConnection;
    private static volatile boolean sGranted;
    private static CountDownLatch sLatch;

    public static synchronized int openDevice(Context context, String nameContains) {
        close();
        UsbManager manager = (UsbManager) context.getSystemService(Context.USB_SERVICE);
        HashMap<String, UsbDevice> devices = manager.getDeviceList();
        UsbDevice found = null;
        for (UsbDevice device : devices.values()) {
            String product = device.getProductName();
            if (product != null && product.contains(nameContains)) {
                found = device;
                break;
            }
        }
        if (found == null) {
            Log.w(TAG, "device not found: " + nameContains);
            return -1;
        }
        if (!manager.hasPermission(found)) {
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
                return -2;
            }
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
