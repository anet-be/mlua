#!/usr/bin/env python3

import os
import subprocess
import resource
from collections import OrderedDict

# environment variables needed to run ydb locally in the current directory
Env = {
    'ydb_xc_cstrlib': './cstrlib.xc',
    'ydb_routines': '. ' + os.environ['ydb_routines'],
}


def user_time(user_func):
    """ Execute user_func and return user mode time spent doing so """
    usage_start = resource.getrusage(resource.RUSAGE_CHILDREN)
    user_func()
    usage_end = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu_time = usage_end.ru_utime - usage_start.ru_utime
    return cpu_time

def benchmark(mroutine, *args, repetions=int(os.getenv('mlua_benchmark_repetitions', 10))):
    """ Run mroutine from _benchmark.m repetions times and return the minimum time taken
        args = command line parameters passed to M routine
    """
    # set up environment so that dbase can run
    env = os.environ.copy()
    env.update(Env)
    func = lambda: subprocess.run(['gtm', '-run', mroutine+'^%benchmark'] + list(args), env=env)
    minimum = min(user_time(func) for _i in range(repetions))
    return minimum

def main():
    # Note: I tried to get rid of the init time compensation by making it neglegible,
    # but actually, most of it is ydb load time (~30ms) which we can't reduce
    init_time = benchmark('init')
    print(f"init: {init_time:0.3f}s")

    sizes = [1_000_000, 1_000, 10]
    routines = OrderedDict(
        # dicts of:  hash_size:iterations
        # set so that each test takes a couple of seconds -- enough so load time doesn't swamp result
        luaSHA      = {1_000_000:1,   1_000:500,    10:500},
        cmumpsSHA = {1_000_000:100, 1_000:50_000, 10:50_000},
        goSHA = {1_000_000:1, 1_000:10, 10:100},
    )

    # Only run cmumps if it was able to be installed
    if not os.path.exists('cstrlib.so'):  routines.pop('cmumpsSHA')
    if not os.path.exists('brocr'):  routines.pop('goSHA')

    debug = False
    for size in sizes:
        for routine, iterdict in routines.items():
                iterations = iterdict[size]
                raw = benchmark('test', routine, str(iterations), str(size))
                result = raw-init_time
                per_iteration = (result) / iterations
                print(f"{per_iteration*1000000:7.0f}us {routine:>10s} for {str(size)+' byte chunks':<21}", end=' ')
                if debug:
                    print(f"({result:0.3f}s ({raw:0.3f}s-init) for {iterations} iterations / {iterations})", end=' ')
                print()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print()
