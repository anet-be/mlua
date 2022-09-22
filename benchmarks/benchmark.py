#!/usr/bin/env python3

import os
import time
import subprocess
import resource
from collections import OrderedDict, defaultdict, namedtuple

Debug = 1   # Increase to 1 or 2 for debug output

# environment variables needed to run ydb with source files in the current directory
Env = {
    'ydb_xc_cstrlib': './cstrlib.xc',
    'ydb_routines': '. ' + os.environ['ydb_routines'],
    'LUA_CPATH': './?.so;;',
}


def measure_time(user_func):
    """ Execute user_func and return real time spent doing so """
    start = time.perf_counter()
    process_info = user_func()
    end = time.perf_counter()
    real_time = end - start
    return process_info, real_time

def calc_init_time():
    """ Calculate how long init time is so we can compensate for it in the measure python timings
        Note: I tried to get rid of the init time compensation by making it neglegible,
        but actually, most of it is ydb load time (~30ms) which we can't reduce
    """
    init_time, _ = benchmark('init', repetitions=10)
    print(f"init: {init_time:0.3f}s")
    return init_time

def output2float(output):
    """ Return the output of mroutine^%benchmark converted to a float """
    last_output_line = output.strip().split('\n')[-1]  # use only last time of output -- to allow process to print some debugging info on previous lines
    if last_output_line == '': return 0.0
    return float(last_output_line)

def benchmark(mroutine, *args, repetitions=int(os.getenv('mlua_benchmark_repetitions', 10))):
    """ Run mroutine from _benchmark.m repetitions times and return the average time taken
        args = command line parameters passed to M routine
        return real_time, user_time (in seconds)
          'real_time' is the amount of actual time taken incuding M function init (setup)
          'user_time' is the amount of user-only cpu time taken for just the inner loop
            (measured using MLua after M init is complete -- i.e. more accurate)
          The real time is necessary to compare because goSHA includes lots of
            system_time latency -- which the user_time doesn't capture
        Note: I have tinkered with using minimum instead of average, but average is more repeatable
    """
    # set up environment so that dbase can run
    env = os.environ.copy()
    env.update(Env)
    func = lambda: subprocess.run(['gtm', '-run', mroutine+'^%benchmark'] + list(args), env=env, capture_output=True, text=True)
    real_timings = []
    user_timings = []
    for _i in range(repetitions):
        process_info, real_time = measure_time(func)
        real_timings += [real_time]
        user_timings += [output2float(process_info.stdout) / 1_000_000]
    real_time = sum(real_timings) / repetitions
    user_time = sum(user_timings) / repetitions
    if Debug >= 2:
        print(f"real_time: {real_time}")
        print(f"user_time: {user_time}")
    return real_time, user_time

def main():
    print("Benchmarks produced below are calculated by running each function in a tight M loop many times")
    init_time = calc_init_time()    # calc M initialization time to compensate for
    sizes = [1_000_000, 1_000, 10]
    routines = OrderedDict(
        # dicts of:  hash_size:iterations
        # set so that each test takes a couple of seconds -- enough so load time doesn't swamp result
        goSHA       = {1_000_000:1,    1_000:10,        10:100},
        luaSHA      = {1_000_000:2,    1_000:1000,     10:10000},
        cmumpsSHA = {1_000_000:100, 1_000:100_000, 10:100_000},
    )

    # Only run cmumps if it was able to be installed
    if not os.path.exists('cstrlib.so'):  routines.pop('cmumpsSHA')
    if not os.path.exists('brocr'):  routines.pop('goSHA')

    results = defaultdict(lambda: defaultdict(dict))
    for size in sizes:
        for routine, iterdict in routines.items():
                iterations = iterdict[size]
                raw_time, user_time = benchmark('test', routine, str(iterations), str(size))
                real_time = raw_time - init_time
                real_time_per_iter = real_time / iterations
                user_time_per_iter = user_time / iterations
                results[routine][size] = dict(real=real_time_per_iter, user=user_time_per_iter)
                print(f"{real_time_per_iter*1000000:7.0f}us {routine:>10s} for {str(size)+' byte chunks':<21}", end=' ')
                if Debug:
                    print(f"({real_time:0.3f}s ({raw_time:0.3f}s-init) for {iterations} iterations / {iterations})", end=' ')
                print()

    def print_results(results, time_type):
        print(f"{'data size:':>15s}   {'1MB':>7}   {'1KB':>7}   {'10B':>7}  ")
        for routine, sizes in results.items():
            print(f"{routine:15s} ", end='')
            for size, result in sizes.items():
                print(f"{result[time_type]*1000000:7.0f}us ", end='')
            print()

    print("\nSummary - real time measured:")
    print_results(results, 'real')
    print("\nSummary - user time measured:")
    print_results(results, 'user')


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print()
