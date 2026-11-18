"""Clock-aligned UI CPU placement and frequency, without changing governors."""
import argparse
import csv
import io
import json
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('capture', type=Path)
    parser.add_argument('--processor', default='D:/.tool/codex-temp/reader-adb-perf/trace_processor_shell.exe')
    args = parser.parse_args()
    report = json.loads((args.capture / 'capture.json').read_text())
    procedure = json.loads((args.capture / 'procedure.json').read_text())
    package = procedure['package']
    if not re.fullmatch(r'[a-z0-9._]+\.readerbenchmark', package):
        raise ValueError('Unexpected package')
    c = min(report['calibration'], key=lambda c: c['dartEndUs'] - c['dartBeginUs'])
    offset = (c['dartBeginUs'] + c['dartEndUs']) / 2 - c['monoNs'] / 1000
    boot_delta = c['elapsedNs'] - c['monoNs']
    start = round((report['startedUs'] - offset) * 1000 + boot_delta)
    stop = round((report['stoppedUs'] - offset) * 1000 + boot_delta)
    sql = f'''
CREATE PERFETTO TABLE frequencies AS
SELECT tr.cpu, c.ts, LEAD(c.ts,1,{stop}) OVER (PARTITION BY c.track_id ORDER BY c.ts) AS stop,
       c.value AS khz
FROM counter c JOIN cpu_counter_track tr ON c.track_id=tr.id WHERE tr.name='cpufreq';
CREATE PERFETTO TABLE ui_running AS
SELECT t.tid,t.name,s.cpu,MAX(s.ts,{start}) AS ts,MIN(s.ts+s.dur,{stop}) AS stop
FROM sched s JOIN thread t USING(utid) JOIN process p USING(upid)
WHERE (p.name='{package}' OR p.cmdline GLOB '{package}*')
AND (t.tid=p.pid OR t.name GLOB '*.ui') AND s.ts<{stop} AND s.ts+s.dur>{start};
SELECT u.tid,u.name,u.cpu,ROUND(SUM(u.stop-u.ts)/1e6,3) AS running_ms,
 (SELECT ROUND(SUM(MAX(0,MIN(f.stop,v.stop)-MAX(f.ts,v.ts)) * f.khz) /
   NULLIF(SUM(MAX(0,MIN(f.stop,v.stop)-MAX(f.ts,v.ts))),0),0)
  FROM ui_running v JOIN frequencies f ON f.cpu=v.cpu AND f.ts<v.stop AND f.stop>v.ts
  WHERE v.tid=u.tid AND v.cpu=u.cpu) AS running_weighted_khz
FROM ui_running u GROUP BY u.tid,u.cpu ORDER BY u.tid,u.cpu;
'''
    source = args.capture / 'cpu-schedule.sql'
    source.write_text(sql)
    result = subprocess.run([args.processor, 'query', '--format', 'csv', '--no-progress', '-f', str(source), str(args.capture / 'trace.pftrace')], capture_output=True, check=True)
    (args.capture / 'cpu-schedule.csv').write_bytes(result.stdout)
    rows = list(csv.DictReader(io.StringIO(result.stdout.decode())))
    (args.capture / 'cpu-schedule.json').write_text(json.dumps({'rows': rows, 'limits': 'Running-weighted kernel frequency counters, not cycles or CPU power. Missing frequency is unknown. No frequency or affinity settings changed.'}, indent=2))
    print(args.capture.name, rows)


if __name__ == '__main__':
    main()
