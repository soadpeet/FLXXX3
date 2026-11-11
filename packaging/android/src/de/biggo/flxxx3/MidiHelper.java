package de.biggo.flxxx3;

import android.content.Context;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.media.midi.MidiDevice;
import android.media.midi.MidiDeviceInfo;
import android.media.midi.MidiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Thin wrapper around android.media.midi.MidiManager for the native MIDI
 * backend (AMidi). It lists MIDI devices and opens them synchronously. The
 * native side then takes the returned MidiDevice object to AMidi.
 *
 * Note: openDevice() blocks until the system has opened the device, so it must
 * not be called from the main thread.
 */
public class MidiHelper {
    private static final String TAG = "MixxxMidi";

    private final MidiManager manager;
    private final UsbManager usbManager;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Map<Integer, MidiDevice> openDevices = new HashMap<>();

    public MidiHelper(Context context) {
        manager = (MidiManager) context.getSystemService(Context.MIDI_SERVICE);
        usbManager = (UsbManager) context.getSystemService(Context.USB_SERVICE);
        if (manager == null) {
            Log.w(TAG, "MidiManager not available");
        }
    }

    /**
     * Number of USB devices currently attached to the phone (without hubs that
     * the system does not expose). The MIDI service lists a controller a bit
     * later than the USB service, so callers can use this to decide whether
     * waiting for a MIDI device makes sense.
     */
    public int usbDeviceCount() {
        if (usbManager == null) {
            return 0;
        }
        try {
            return usbManager.getDeviceList().size();
        } catch (Exception e) {
            Log.w(TAG, "Cannot list USB devices: " + e);
            return 0;
        }
    }

    private static String clean(String text) {
        return text == null ? "" : text.replace('\t', ' ').replace('\n', ' ');
    }

    /**
     * One line per device, tab separated:
     * id, type, inputPorts, outputPorts, manufacturer, product, name, serial,
     * usbVendorId, usbProductId (-1 if unknown).
     * "inputPorts" are ports that accept data from the app (app -> device),
     * "outputPorts" are ports that deliver data to the app (device -> app).
     */
    @SuppressWarnings("deprecation")
    public String listDevices() {
        StringBuilder out = new StringBuilder();
        if (manager == null) {
            return "";
        }
        for (MidiDeviceInfo info : manager.getDevices()) {
            Bundle props = info.getProperties();
            int vendorId = -1;
            int productId = -1;
            try {
                UsbDevice usb = props.getParcelable(MidiDeviceInfo.PROPERTY_USB_DEVICE);
                if (usb != null) {
                    vendorId = usb.getVendorId();
                    productId = usb.getProductId();
                }
            } catch (Exception e) {
                Log.w(TAG, "No USB device info: " + e);
            }
            out.append(info.getId()).append('\t')
                    .append(info.getType()).append('\t')
                    .append(info.getInputPortCount()).append('\t')
                    .append(info.getOutputPortCount()).append('\t')
                    .append(clean(props.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER))).append('\t')
                    .append(clean(props.getString(MidiDeviceInfo.PROPERTY_PRODUCT))).append('\t')
                    .append(clean(props.getString(MidiDeviceInfo.PROPERTY_NAME))).append('\t')
                    .append(clean(props.getString(MidiDeviceInfo.PROPERTY_SERIAL_NUMBER))).append('\t')
                    .append(vendorId).append('\t')
                    .append(productId).append('\n');
        }
        return out.toString();
    }

    /** Opens the device with the given id and keeps it open until closeDevice(). Returns null on failure. */
    public synchronized MidiDevice openDevice(int deviceId, int timeoutMs) {
        if (manager == null) {
            return null;
        }
        MidiDevice already = openDevices.get(deviceId);
        if (already != null) {
            return already;
        }
        MidiDeviceInfo target = null;
        for (MidiDeviceInfo info : manager.getDevices()) {
            if (info.getId() == deviceId) {
                target = info;
                break;
            }
        }
        if (target == null) {
            Log.w(TAG, "No MIDI device with id " + deviceId);
            return null;
        }
        final CountDownLatch latch = new CountDownLatch(1);
        final AtomicReference<MidiDevice> result = new AtomicReference<>();
        manager.openDevice(target, new MidiManager.OnDeviceOpenedListener() {
            @Override
            public void onDeviceOpened(MidiDevice device) {
                result.set(device);
                latch.countDown();
            }
        }, mainHandler);
        try {
            if (!latch.await(timeoutMs, TimeUnit.MILLISECONDS)) {
                Log.w(TAG, "Timeout opening MIDI device " + deviceId);
                return null;
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return null;
        }
        MidiDevice device = result.get();
        if (device == null) {
            Log.w(TAG, "System failed to open MIDI device " + deviceId);
            return null;
        }
        openDevices.put(deviceId, device);
        Log.i(TAG, "Opened MIDI device " + deviceId);
        return device;
    }

    public synchronized void closeDevice(int deviceId) {
        MidiDevice device = openDevices.remove(deviceId);
        if (device == null) {
            return;
        }
        try {
            device.close();
            Log.i(TAG, "Closed MIDI device " + deviceId);
        } catch (Exception e) {
            Log.w(TAG, "Error closing MIDI device " + deviceId + ": " + e);
        }
    }
}
