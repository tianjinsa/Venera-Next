"""Share a runner-sized parallelism budget and measure expensive CI commands.

Only standard-library modules are used, including on macOS and Windows runners.
This configures concurrency; it cannot make serial compilation or I/O use all CPUs.
"""

import argparse
import ctypes
import math
import os
from pathlib import Path
import subprocess
import sys
import time
import uuid

try:
    import resource
except ImportError:  # Windows has no getrusage.
    resource = None


GIB = 1024 ** 3
CGROUP = Path("/sys/fs/cgroup")


def read_text(path):
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def positive_int(value):
    try:
        number = int(value)
        return number if number > 0 else None
    except (TypeError, ValueError):
        return None


def available_cpus(cgroup=CGROUP):
    counts = [os.cpu_count() or 1]
    if hasattr(os, "sched_getaffinity"):
        try:
            counts.append(len(os.sched_getaffinity(0)) or 1)
        except OSError:
            pass
    # GitHub's VMs expose all CPUs directly. Containers may additionally cap CPU
    # time; support the usual unified and legacy cgroup mounts as well.
    quota = read_text(cgroup / "cpu.max").split()
    if len(quota) != 2:
        quota = [read_text(cgroup / "cpu/cpu.cfs_quota_us"),
                 read_text(cgroup / "cpu/cpu.cfs_period_us")]
    amount, period = (positive_int(part) for part in quota)
    if amount and period:
        counts.append(math.ceil(amount / period))
    return max(1, min(counts))


def host_memory():
    if sys.platform == "win32":
        class MemoryStatus(ctypes.Structure):
            _fields_ = [("length", ctypes.c_ulong), ("load", ctypes.c_ulong),
                        *[(name, ctypes.c_ulonglong) for name in (
                            "total_physical", "available_physical", "total_page",
                            "available_page", "total_virtual", "available_virtual",
                            "available_extended")]]

        status = MemoryStatus()
        status.length = ctypes.sizeof(status)
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
            return status.total_physical
        return None
    if sys.platform == "darwin":
        result = subprocess.run(["sysctl", "-n", "hw.memsize"],
                                text=True, capture_output=True, check=False)
        return positive_int(result.stdout)
    try:
        return os.sysconf("SC_PHYS_PAGES") * os.sysconf("SC_PAGE_SIZE")
    except (ValueError, OSError, AttributeError):
        return None


def available_memory(cgroup=CGROUP):
    limits = [host_memory(),
              positive_int(read_text(cgroup / "memory.max")),
              positive_int(read_text(cgroup / "memory/memory.limit_in_bytes"))]
    return min((limit for limit in limits if limit and limit > 0), default=None)


def resource_plan(cpus, memory):
    # Leave 2 GiB for the OS, Dart compiler, JVM and other coordinator processes.
    # These conservative budgets are caps, not predictions of actual usage.
    usable = max(0, memory - 2 * GIB) if memory else None
    tests = min(cpus, max(1, int(usable // (1.5 * GIB)))) if memory else cpus
    builds = min(cpus, max(1, usable // GIB)) if memory else cpus
    return {
        "CI_CPU_COUNT": str(cpus),
        "CI_MEMORY_GIB": f"{memory / GIB:.2f}" if memory else "unknown",
        "CI_TEST_JOBS": str(tests),
        "CI_BUILD_JOBS": str(builds),
        "CMAKE_BUILD_PARALLEL_LEVEL": str(builds),
        "CTEST_PARALLEL_LEVEL": str(tests),
        "CARGO_BUILD_JOBS": str(builds),
        "RUST_TEST_THREADS": str(tests),
    }


def write_environment(path, values):
    # Preserve existing Gradle options, even when they contain newlines. A fresh
    # delimiter avoids turning an option into an unrelated GITHUB_ENV entry.
    with path.open("a", encoding="utf-8") as output:
        for key, value in values.items():
            delimiter = "ci_resources_" + uuid.uuid4().hex
            while delimiter in value.splitlines():
                delimiter = "ci_resources_" + uuid.uuid4().hex
            output.write(f"{key}<<{delimiter}\n{value}\n{delimiter}\n")


def summary(text):
    print(text, flush=True)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(os.environ["GITHUB_STEP_SUMMARY"]).open("a", encoding="utf-8") as output:
            output.write(text + "\n\n")


def configure():
    plan = resource_plan(available_cpus(), available_memory())
    jobs = plan["CI_BUILD_JOBS"]
    plan["GRADLE_OPTS"] = (os.environ.get("GRADLE_OPTS", "")
                           + f" -Dorg.gradle.parallel=true -Dorg.gradle.workers.max={jobs}").strip()
    if os.environ.get("GITHUB_ENV"):
        write_environment(Path(os.environ["GITHUB_ENV"]), plan)
    summary("### Runner 资源预算\n\n"
            "| 可用 CPU | 内存 GiB | 测试并发 | 编译并发 |\n"
            "| ---: | ---: | ---: | ---: |\n"
            f"| {plan['CI_CPU_COUNT']} | {plan['CI_MEMORY_GIB']} | "
            f"{plan['CI_TEST_JOBS']} | {jobs} |\n\n"
            "预算预留 2 GiB；每个测试进程按 1.5 GiB、编译任务按 1 GiB 限制。"
            "文件内串行、编译队列及 I/O 仍可能限制 CPU 利用率。")


def run_measured(label, command):
    started = time.monotonic()
    before = resource.getrusage(resource.RUSAGE_CHILDREN) if resource else None
    try:
        status = subprocess.call(command)
        if status < 0:
            status = 128 - status
    except OSError as error:
        print(f"Cannot start CI command: {error}", file=sys.stderr)
        status = 127
    except KeyboardInterrupt:
        status = 130
    elapsed = max(time.monotonic() - started, 0.001)
    cpu, occupancy, rss = "—", "—", "—"
    if resource:
        after = resource.getrusage(resource.RUSAGE_CHILDREN)
        seconds = after.ru_utime + after.ru_stime - before.ru_utime - before.ru_stime
        cores = seconds / elapsed
        budget = positive_int(os.environ.get("CI_CPU_COUNT")) or available_cpus()
        cpu = f"{cores:.2f}"
        occupancy = f"{cores / budget:.1%}"
        rss_bytes = after.ru_maxrss * (1 if sys.platform == "darwin" else 1024)
        rss = f"{rss_bytes / GIB:.2f}"
    label = label.replace("|", "/").replace("\n", " ").replace("\r", " ")
    summary(f"### {label}\n\n"
            "| 退出码 | 耗时 秒 | 平均占用 CPU 核数 | 占 CPU 预算 | 最大子进程 RSS GiB |\n"
            "| ---: | ---: | ---: | ---: | ---: |\n"
            f"| {status} | {elapsed:.2f} | {cpu} | {occupancy} | {rss} |\n\n"
            "CPU 为已退出子进程及其已回收后代的 user+system 时间，不含常驻构建守护进程；"
            "RSS 是最大单进程值，并非同时运行的进程树总峰值。Windows 仅记录耗时与退出码。")
    return status


def main():
    # Actions consumes UTF-8 on all runners, including Windows redirected output.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="mode", required=True)
    commands.add_parser("configure")
    runner = commands.add_parser("run")
    runner.add_argument("--label", required=True)
    runner.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.mode == "configure":
        configure()
        return 0
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("run requires a command after --")
    return run_measured(args.label, command)


if __name__ == "__main__":
    sys.exit(main())
