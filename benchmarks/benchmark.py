#!/usr/bin/env python3

import os
import time
import subprocess
import resource
from collections import OrderedDict, defaultdict, namedtuple

#Set Debug to >=1 to print process timings, and >=3 to also print raw timings
Debug = 0   # increase to >0 for debug output

# environment variables needed to run ydb with source files in the current directory
Env = {
    'MLUA_INIT': '',
    'ydb_xc_cstrlib': './cstrlib.xc',
    'ydb_routines': '. ',

    # use .lua & .so files built by mlua in both . and .. in preference to others in the path
    # this ensures we are testing against our own builds instead of system installed libs
    'LUA_PATH': './?.lua;../?.lua;' + os.getenv('LUA_PATH','') + ';;',
    'LUA_CPATH': './?.so;../?.so;' + os.getenv('LUA_CPATH','') + ';;',
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
    _, init_time, _ = benchmark('init', ignore_user_time=True, repetitions=10)
    print(f"init: {init_time:0.3f}s")
    return init_time

def run_mroutine(mroutine, *args):
    """ Run mroutine and return process_info. Captured output is returned in process_info.stdout """
    # set up environment so that dbase can run
    env = os.environ.copy()
    env.update(Env)
    command = ['gtm', '-run', mroutine+'^%benchmark'] + list(args)
    process_info = subprocess.run(command, env=env, capture_output=True, encoding='utf-8', errors='namereplace')
    return process_info

def detect_lua_module(module):
    """ Use MLua to check whether Lua has module installed. Return True/False
        This is done through ydb and mlua instead of directly through lua to ensure the lua environment is set up the same.
    """
    process_info = run_mroutine('detectLuaModule', module)
    if process_info.stderr:
        raise Exception(process_info.stderr)
    return int(process_info.stdout.strip('\n').split('\n')[-1])

def benchmark(mroutine, *args, ignore_user_time=False, repetitions=int(os.getenv('mlua_benchmark_repetitions', 10))):
    """ Run mroutine from _benchmark.m repetitions times and return the average time taken
        args = command line parameters passed to M routine
        ignore_user_time: set to True to ignore the user time recorded by MLua -- used to init's real time
        return retval, real_time, user_time (in seconds)
          retval is the return value of the function, which it must print on the second-to-last output line
          'real_time' is the amount of actual time taken incuding M function init (setup)
          'user_time' is the amount of user-only cpu time taken for just the inner loop,
            which the function must print on the last time (measured using MLua after M init
            is complete -- i.e. more accurate than real_time)
          The real time is necessary to compare because shellSHA includes lots of
            system_time latency -- which the user_time doesn't capture
        Note: I have tinkered with using minimum instead of average, but average is more repeatable
    """
    func = lambda: run_mroutine(mroutine, *args)
    real_timings = []
    user_timings = []
    for _i in range(repetitions):
        process_info, raw_real_time = measure_time(func)
        lines = process_info.stdout.strip('\n').split('\n')
        # Print any debugging output produced by the mroutine (lines before the last two)
        for line in lines[:-2]:
            print('>', line)
        # get result of routine; e.g. hash value from SHA or length from Strip
        retval = ''
        if len(lines) >= 2:
            retval = lines[-2]
        raw_user_time = 0.0 if ignore_user_time else float(lines[-1]) / 1e6
        real_timings += [raw_real_time]
        user_timings += [raw_user_time]
    real_time = sum(real_timings) / repetitions
    user_time = sum(user_timings) / repetitions
    if Debug >= 3:
        print(f"real_time: {real_time}")
        print(f"user_time: {user_time}")
    return retval, real_time, user_time

def tohuman(number, dp=0):
    """ Return human-readable version of a number with dp decimal points of precision """
    if number < 1e-3:
        return f"{number*1e6:.{dp}f}u"
    if number < 1:
        return f"{number*1000:.{dp}f}m"
    if number >= 1e6:
        return f"{number/1e6:.{dp}f}m"
    if number >= 1000:
        return f"{number/1000:.{dp}f}k"
    return f"{int(number)}"


# ~~~ Define list of tests to perform
Sizes = [10, 1000, 1_000_000]

# List of mroutine test names {datasize:iterations, datasize:iterations, ...}
Routines = OrderedDict(
    # dicts of:  hash_size:iterations
    # set so that each test takes a couple of seconds -- enough so load time doesn't swamp result
    shellSHA    = {10:200, 1000:200, 1_000_000:1},
    pureluaSHA = {10:10_000, 1000:2000, 1_000_000:2},
    luaCLibSHA = {10:200_000, 1000:100_000, 1_000_000:100},
    cmumpsSHA = {10:100_000, 1000:100_000, 1_000_000:100},

    luaStripCharsPrm = {10:200_000, 1000:100_000, 1_000_000:100},
    luaStripCharsDb = {10:100_000, 1000:50_000, 1_000_000:100},
    cmumpsStripChars = {10:1000_000, 1000:10_000, 1_000_000:10},
    mStripChars = {10:100_000, 1000:20_000, 1_000_000:100},
)

# Various SHA512 results expected -- to check whether the test is running correctly
class Expected_results:
    shellSHA = pureluaSHA = luaCLibSHA = cmumpsSHA = {
        10: '8772d22407ac282809a75706f91fab898adea0235f1d304d85c1c48650c283413e533eba63880c51be67e35dfc3433ddbe78e73d459511aaf29251a64a803884',
        1000: '7319dbae7e935f940b140f8b9d8e4d5e2509d634fb67041d8828833dcf857cfecda45282b54c0a77e2875185381d95791594dbf1a0f3db5cae71d95617287c18',
        1_000_000: '7a0712c75269ad5fbf829e04f116701899bcbefc5f07e4610fbaddf493ee2b917f84f1f0107f0ee95b420efc3c4cd6b687ee944a52351fc0c52eba260b11bed6',
    }
    luaStripCharsPrm = luaStripCharsDb = cmumpsStripChars = mStripChars = {
        10:'8', 1000:'998', 1_000_000:'999998',
    }


def main():
    print("Benchmarks produced below are calculated by running each function in a tight M loop many times.")
    init_time = calc_init_time()    # calc M initialization time to compensate for
    # Only run cmumps if it was able to be installed
    if not os.path.exists('cstrlib.so'):  Routines.pop('cmumpsSHA'); Routines.pop('cmumpsStripChars'); print(f"Skipping uninstalled cmumpsSHA. To install, run: make")
    if not os.path.exists('brocr'):  Routines.pop('shellSHA'); print(f"Skipping uninstalled shellSHA. To install, run: make")
    if not detect_lua_module('hmac'): Routines.pop('luaCLibSHA'); print(f"Skipping uninstalled luaCLibSHA. To install, run: luarocks install hmac")

    print(f"Running {len(Sizes)*len(Routines)} tests ...")
    results = defaultdict(lambda: defaultdict(dict))
    for size in Sizes:
        for routine, iterdict in Routines.items():
                iterations = iterdict[size]
                try:
                    retval, raw_time, user_time = benchmark('test', routine, str(iterations), str(size))
                except ValueError as e:
                    e.args = (f"{e.args[0]} -- while trying to benchmark routine {routine}",) + e.args[1:]
                    raise e
                # repeat with greater double the iterations if the test was so short that it was swamped by init time
                while raw_time < init_time*3:
                    print(f"Warning: {routine}({tohuman(size)}B) x{iterations} test is swamped by init time. Iterations should be increased. Doubling and re-testing.")
                    iterations *= 2
                    iterdict[size] = iterations
                    retval, raw_time, user_time = benchmark('test', routine, str(iterations), str(size))
                expected_result = getattr(Expected_results, routine)[size]
                if retval != expected_result:
                    print(f"Warning: {routine} returned: {retval!r} instead of the expected result: {expected_result!r}")
                real_time = raw_time - init_time
                real_time_per_iter = real_time / iterations
                user_time_per_iter = user_time / iterations
                results[routine][size] = dict(real=real_time_per_iter, user=user_time_per_iter)
                print(f"{real_time_per_iter*1e6:11,.1f}us {routine:>18s} for {tohuman(size)+'B chunks':<21}", end=' ')
                if Debug:
                    print(f"({real_time:0.3f}s ({raw_time:0.3f}s-init) for {iterations} iterations / {iterations})", end=' ')
                print()

    def print_results(results, time_type, sizes):
        print(f"{'data size:':>18s}  " + ''.join(f"{tohuman(size):>11}B  " for size in sizes))
        for routine, sizes in results.items():
            print(f"{routine:18s} ", end='')
            for size, result in sizes.items():
                print(f"{result[time_type]*1e6:11,.1f}us ", end='')
            print()

    print("\nREAL time measured")
    print_results(results, 'real', Sizes)
    print("\nUSER time measured")
    print_results(results, 'user', Sizes)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print()
