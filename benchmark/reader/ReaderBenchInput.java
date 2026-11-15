import android.os.SystemClock;
import android.view.InputDevice;
import android.view.InputEvent;
import android.view.MotionEvent;
import java.lang.reflect.Method;
import java.util.concurrent.locks.LockSupport;

/** Shell-UID touch injector. No app/system settings, files, or reader logic. */
public final class ReaderBenchInput {
    private static Object manager;
    private static Method inject;
    private static final StringBuilder records = new StringBuilder();

    private static void waitUntil(long deadlineNs) {
        long remaining;
        while ((remaining = deadlineNs - System.nanoTime()) > 0) {
            LockSupport.parkNanos(remaining);
        }
    }

    private static void send(long deadlineNs, long downMs, int action, float x) throws Exception {
        waitUntil(deadlineNs);
        long actualNs = System.nanoTime();
        long eventMs = SystemClock.uptimeMillis();
        MotionEvent event = MotionEvent.obtain(downMs, eventMs, action, x, 1200f, 0);
        event.setSource(InputDevice.SOURCE_TOUCHSCREEN);
        try {
            // WAIT_FOR_RESULT validates acceptance without waiting for the app
            // to finish handling the event. Absolute deadlines retain cadence.
            if (!((Boolean) inject.invoke(manager, event, 1))) {
                throw new IllegalStateException("Input injection rejected");
            }
        } finally {
            event.recycle();
        }
        if (records.length() != 0) records.append(',');
        records.append('[').append(deadlineNs).append(',').append(actualNs)
            .append(',').append(eventMs).append(',').append(downMs)
            .append(',').append(action).append(',').append(x).append(']');
    }

    public static void main(String[] args) throws Exception {
        if (args.length != 6) throw new IllegalArgumentException("count durationMs gapMs stepMs forward alternate");
        int count = Integer.parseInt(args[0]);
        int durationMs = Integer.parseInt(args[1]);
        int gapMs = Integer.parseInt(args[2]);
        int stepMs = Integer.parseInt(args[3]);
        boolean forward = Boolean.parseBoolean(args[4]);
        boolean alternate = Boolean.parseBoolean(args[5]);
        if (count < 1 || count > 512 || durationMs < 16 || durationMs > 2000 ||
                gapMs < 0 || gapMs > 5000 || stepMs < 2 || stepMs > 16) {
            throw new IllegalArgumentException("Invalid bounded touch scenario");
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
        int steps = Math.max(2, durationMs / stepMs);
        for (int index = 0; index < count; index++) {
            boolean left = forward ^ (alternate && index % 2 == 1);
            float from = left ? 920f : 160f, to = left ? 160f : 920f;
            long gestureNs = startNs + index * (durationMs + (long) gapMs) * 1_000_000L;
            waitUntil(gestureNs);
            long downMs = SystemClock.uptimeMillis();
            boolean down = false;
            try {
                send(gestureNs, downMs, MotionEvent.ACTION_DOWN, from);
                down = true;
                for (int step = 1; step < steps; step++) {
                    send(gestureNs + durationMs * 1_000_000L * step / steps, downMs,
                        MotionEvent.ACTION_MOVE, from + (to - from) * step / steps);
                }
                send(gestureNs + durationMs * 1_000_000L, downMs, MotionEvent.ACTION_UP, to);
                down = false;
            } finally {
                if (down) send(System.nanoTime(), downMs, MotionEvent.ACTION_CANCEL, to);
            }
        }
        System.out.println("READER_BENCH_INPUT_JSON {\"durationMs\":" + durationMs +
            ",\"gapMs\":" + gapMs + ",\"stepMs\":" + stepMs + ",\"events\":[" + records + "]}");
    }
}
