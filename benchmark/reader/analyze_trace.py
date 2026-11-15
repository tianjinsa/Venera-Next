"""Analyze one Perfetto trace in one load, within the probe's clock-aligned ROI.

FrameTimeline presentation types and jank attribution remain separate from the
Flutter timing report. Raw output also exposes trace-loss counters.
"""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path, help='Directory with capture.json and trace.pftrace')
    parser.add_argument('--processor', default='D:/.tool/codex-temp/reader-adb-perf/trace_processor_shell.exe')
    args = parser.parse_args()
    report = json.loads((args.capture / 'capture.json').read_text(encoding='utf-8'))
    procedure = json.loads((args.capture / 'procedure.json').read_text(encoding='utf-8'))
    package = procedure['package']
    if not package.endswith('.readerbenchmark') or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789._' for c in package):
        raise ValueError('Unexpected application ID')
    calibration = min(report['calibration'], key=lambda c: c['dartEndUs'] - c['dartBeginUs'])
    offset_us = (calibration['dartBeginUs'] + calibration['dartEndUs']) / 2 - calibration['monoNs'] / 1000
    boot_delta_ns = calibration['elapsedNs'] - calibration['monoNs']
    begin = round((report['startedUs'] - offset_us) * 1000 + boot_delta_ns)
    end = round((report['stoppedUs'] - offset_us) * 1000 + boot_delta_ns)
    sql = f'''
CREATE PERFETTO TABLE reader_window AS SELECT {begin} AS start, {end} AS stop;
CREATE PERFETTO TABLE reader_process AS
  SELECT * FROM process WHERE name = '{package}' OR cmdline GLOB '{package}*';
CREATE PERFETTO TABLE reader_presentations AS
  SELECT a.* FROM actual_frame_timeline_slice a JOIN reader_process p USING(upid), reader_window w
  WHERE a.ts >= w.start AND a.ts < w.stop AND a.layer_name GLOB '*SurfaceView*';
SELECT 'clock_window' AS metric, start, stop FROM reader_window;
SELECT 'trace_bounds' AS metric, start_ts, end_ts FROM trace_bounds;
SELECT 'process' AS metric, upid, pid, name FROM reader_process;
SELECT 'presentation' AS metric, present_type, jank_type, COUNT(*) AS frames
  FROM reader_presentations GROUP BY present_type, jank_type;
SELECT 'layer' AS metric, layer_name, COUNT(*) AS frames
  FROM reader_presentations GROUP BY layer_name;
SELECT 'thread_cpu' AS metric, t.name, COUNT(*) AS slices,
  ROUND(SUM(MAX(0, MIN(s.ts+s.dur,w.stop)-MAX(s.ts,w.start)))/1e6,3) AS cpu_ms
  FROM sched s JOIN thread t USING(utid) JOIN reader_process p USING(upid), reader_window w
  WHERE s.ts < w.stop AND s.ts+s.dur > w.start
  GROUP BY t.utid ORDER BY cpu_ms DESC LIMIT 20;
SELECT 'thread_state' AS metric, t.name, s.state, COUNT(*) AS slices,
  ROUND(SUM(MAX(0, MIN(s.ts+s.dur,w.stop)-MAX(s.ts,w.start)))/1e6,3) AS total_ms,
  ROUND(MAX(MAX(0, MIN(s.ts+s.dur,w.stop)-MAX(s.ts,w.start)))/1e6,3) AS max_ms
  FROM thread_state s JOIN thread t USING(utid) JOIN reader_process p USING(upid), reader_window w
  WHERE s.ts < w.stop AND s.ts+s.dur > w.start
    AND (t.name GLOB '*.ui' OR t.name GLOB '*.raster' OR t.tid=p.pid)
  GROUP BY t.utid,s.state ORDER BY t.name,total_ms DESC;
SELECT 'app_trace' AS metric, s.name, COUNT(*) AS samples, ROUND(SUM(s.dur)/1e6,3) AS total_ms
  FROM slice s JOIN thread_track tt ON s.track_id=tt.id JOIN thread t USING(utid)
  JOIN reader_process p USING(upid), reader_window w
  WHERE s.ts BETWEEN w.start AND w.stop AND (s.name GLOB 'ReaderBench*' OR s.name GLOB '*GC*')
  GROUP BY s.name;
SELECT 'trace_health' AS metric, name, idx, severity, value FROM stats
  WHERE value>0 AND severity IN ('data_loss','error');
SELECT 'actual_frame' AS metric, ts, dur, present_type, jank_type, surface_frame_token, display_frame_token
  FROM reader_presentations ORDER BY ts;
'''
    sql_path = args.capture / 'analysis.sql'
    sql_path.write_text(sql, encoding='utf-8')
    result = subprocess.run([args.processor, 'query', '--format', 'csv', '--no-progress', '-f', str(sql_path), str(args.capture / 'trace.pftrace')], capture_output=True)
    (args.capture / 'perfetto-analysis.csv').write_bytes(result.stdout)
    (args.capture / 'perfetto-analysis-errors.txt').write_bytes(result.stderr)
    if result.returncode:
        raise RuntimeError(result.stderr.decode('utf-8', errors='replace'))
    print('Saved', args.capture / 'perfetto-analysis.csv')


if __name__ == '__main__':
    main()
