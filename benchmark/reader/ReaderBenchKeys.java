import android.os.SystemClock;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.KeyCharacterMap;
import android.view.KeyEvent;
import java.lang.reflect.Method;
import java.util.concurrent.locks.LockSupport;

/** Replays calibrated DOWN repeats and one UP through Android's input service. */
public final class ReaderBenchKeys {
    private static Object manager;
    private static Method inject;
    private static final StringBuilder records = new StringBuilder();

    private static void waitUntil(long deadlineNs) {
        long remaining;
        while ((remaining = deadlineNs - System.nanoTime()) > 0) {
            LockSupport.parkNanos(remaining);
        }
    }

    private static void send(long deadlineNs, long downMs, int action,
            int keyCode, int repeat) throws Exception {
        waitUntil(deadlineNs);
        long actualNs = System.nanoTime();
        long eventMs = SystemClock.uptimeMillis();
        int flags = repeat == 1 ? KeyEvent.FLAG_LONG_PRESS : 0;
        KeyEvent event = new KeyEvent(downMs, eventMs, action, keyCode, repeat, 0,
            KeyCharacterMap.VIRTUAL_KEYBOARD, 0, flags, InputDevice.SOURCE_KEYBOARD);
        if (!((Boolean) inject.invoke(manager, event, 1))) {
            throw new IllegalStateException("Key injection rejected");
        }
        if (records.length() != 0) records.append(',');
        records.append('[').append(deadlineNs).append(',').append(actualNs)
            .append(',').append(eventMs).append(',').append(downMs)
            .append(',').append(action).append(',').append(keyCode)
            .append(',').append(repeat).append(']');
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 3) throw new IllegalArgumentException("keyCode releaseMs commaSeparatedDownOffsetsMs");
        int code = Integer.parseInt(args[0]);
        int releaseMs = Integer.parseInt(args[1]);
        String[] tokens = args[2].split(",");
        if ((code != 24 && code != 25) || releaseMs < 500 || releaseMs > 20000 ||
                tokens.length < 2 || tokens.length > 512) {
            throw new IllegalArgumentException("Invalid bounded key scenario");
        }
        int[] offsets = new int[tokens.length];
        for (int i = 0; i < tokens.length; i++) {
            offsets[i] = Integer.parseInt(tokens[i]);
            if (offsets[i] < 0 || offsets[i] >= releaseMs ||
                    (i == 0 && offsets[i] != 0) ||
                    (i > 0 && offsets[i] <= offsets[i - 1])) {
                throw new IllegalArgumentException("Invalid key deadlines");
            }
        }
        Class<?> inputClass;
        try {
            inputClass = Class.forName("android.hardware.input.InputManagerGlobal");
        } catch (ClassNotFoundException oldAndroid) {
            inputClass = Class.forName("android.hardware.input.InputManager");
        }
        manager = inputClass.getMethod("getInstance").invoke(null);
        inject = inputClass.getMethod("injectInputEvent", InputEvent.class, int.class);
        long startNs = System.nanoTime() + 100_000_000L;
        waitUntil(startNs);
        long downMs = SystemClock.uptimeMillis();
        boolean down = false;
        try {
            for (int i = 0; i < offsets.length; i++) {
                send(startNs + offsets[i] * 1_000_000L, downMs, KeyEvent.ACTION_DOWN, code, i);
                down = true;
            }
            send(startNs + releaseMs * 1_000_000L, downMs, KeyEvent.ACTION_UP, code, 0);
            down = false;
        } finally {
            if (down) send(System.nanoTime(), downMs, KeyEvent.ACTION_UP, code, 0);
        }
        System.out.println("READER_BENCH_KEYS_JSON {\"releaseMs\":" + releaseMs +
            ",\"events\":[" + records + "]}");
    }
}
