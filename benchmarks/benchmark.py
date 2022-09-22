#!/usr/bin/env python3

import os
import time
import subprocess
import resource
from collections import OrderedDict, defaultdict, namedtuple

Debug = 0   # Increase to 1 or 2 for debug output

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
    init_time, _ = benchmark('init', ignore_user_time=True, repetitions=10)
    print(f"init: {init_time:0.3f}s")
    return init_time

def output2float(output):
    """ Return the output of mroutine^%benchmark converted to a float """
    # Only last line contains the data we want; previous lines are debug output
    lines = output.strip().split('\n')
    if Debug and len(lines) > 1:
        print('\n'.join(lines[:-1]))
    last_output_line = lines[-1]
    return float(last_output_line)

def run_mroutine(mroutine, *args):
    """ Run mroutine and return process_info. Captured output is returned in process_info.stdout """
    # set up environment so that dbase can run
    env = os.environ.copy()
    env.update(Env)
    process_info = subprocess.run(['gtm', '-run', mroutine+'^%benchmark'] + list(args), env=env, capture_output=True, text=True)
    return process_info

def detect_lua_module(module):
    """ Use MLua to check whether Lua has module installed. Return True/False
        This is done through ydb and mlua instead of directly through lua to ensure the lua environment is set up the same.
    """
    process_info = run_mroutine('detectLuaModule', module)
    return int(process_info.stdout)

def benchmark(mroutine, *args, ignore_user_time=False, repetitions=int(os.getenv('mlua_benchmark_repetitions', 10))):
    """ Run mroutine from _benchmark.m repetitions times and return the average time taken
        args = command line parameters passed to M routine
        ignore_user_time: set to True to ignore the user time recorded by MLua -- used to init's real time
        return real_time, user_time (in seconds)
          'real_time' is the amount of actual time taken incuding M function init (setup)
          'user_time' is the amount of user-only cpu time taken for just the inner loop
            (measured using MLua after M init is complete -- i.e. more accurate)
          The real time is necessary to compare because goSHA includes lots of
            system_time latency -- which the user_time doesn't capture
        Note: I have tinkered with using minimum instead of average, but average is more repeatable
    """
    func = lambda: run_mroutine(mroutine, *args)
    real_timings = []
    user_timings = []
    for _i in range(repetitions):
        process_info, raw_real_time = measure_time(func)
        raw_user_time = 0.0 if ignore_user_time else output2float(process_info.stdout) / 1e6
        real_timings += [raw_real_time]
        user_timings += [raw_user_time]
    real_time = sum(real_timings) / repetitions
    user_time = sum(user_timings) / repetitions
    if Debug >= 2:
        print(f"real_time: {real_time}")
        print(f"user_time: {user_time}")
    return real_time, user_time

def tohuman(number):
    """ Return human-readable version of a number """
    if number < 1e-3:
        return f"{int(number*1e6)}u"
    if number < 1:
        return f"{int(number*1000)}m"
    if number >= 1e6:
        return f"{int(number/1e6)}m"
    if number >= 1000:
        return f"{int(number/1000)}k"
    return f"{int(number)}"

def main():
    print("Benchmarks produced below are calculated by running each function in a tight M loop many times.")
    init_time = calc_init_time()    # calc M initialization time to compensate for
    sizes = [1e6, 1000, 10]
    routines = OrderedDict(
        # dicts of:  hash_size:iterations
        # set so that each test takes a couple of seconds -- enough so load time doesn't swamp result
        goSHA       = {1e6:1,    1000:200,        10:200},
        pureluaSHA = {1e6:2,    1000:2000,     10:10_000},
        luaCLibSHA = {1e6:100, 1000:100_000, 10:100_000},
        cmumpsSHA = {1e6:100, 1000:100_000, 10:100_000},
    )

    # Only run cmumps if it was able to be installed
    if not os.path.exists('cstrlib.so'):  routines.pop('cmumpsSHA'); print(f"Skipping uninstalled cmumpsSHA. To install, run: make")
    if not os.path.exists('brocr'):  routines.pop('goSHA'); print(f"Skipping uninstalled goSHA. To install, run: make")
    if not detect_lua_module('hmac'): routines.pop('luaCLibSHA'); print(f"Skipping uninstalled luaCLibSHA. To install, run: luarocks install hmac")

    results = defaultdict(lambda: defaultdict(dict))
    for size in sizes:
        for routine, iterdict in routines.items():
                iterations = iterdict[size]
                raw_time, user_time = benchmark('test', routine, str(iterations), str(size))
                while raw_time < init_time*3:
                    print(f"{routine}({tohuman(size)}B) x{iterations} test is swamped by init time. Iterations should be increased. Doubling and re-testing.")
                    iterations *= 2
                    iterdict[size] = iterations
                    raw_time, user_time = benchmark('test', routine, str(iterations), str(size))
                real_time = raw_time - init_time
                real_time_per_iter = real_time / iterations
                user_time_per_iter = user_time / iterations
                results[routine][size] = dict(real=real_time_per_iter, user=user_time_per_iter)
                print(f"{real_time_per_iter*1e6:9,.0f}us {routine:>10s} for {str(size)+' byte chunks':<21}", end=' ')
                if Debug:
                    print(f"({real_time:0.3f}s ({raw_time:0.3f}s-init) for {iterations} iterations / {iterations})", end=' ')
                print()

    def print_results(results, time_type, sizes):
        print(f"{'data size:':>15s}  " + ''.join(f"{tohuman(size):>9}B  " for size in sizes))
        for routine, sizes in results.items():
            print(f"{routine:15s} ", end='')
            for size, result in sizes.items():
                print(f"{result[time_type]*1e6:9,.0f}us ", end='')
            print()

    print("\nREAL time measured")
    print_results(results, 'real', sizes)
    print("\nUSER time measured")
    print_results(results, 'user', sizes)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print()
