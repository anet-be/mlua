#!/usr/bin/env python3

import os
import subprocess
import resource
from collections import OrderedDict

# environment variables needed to run ydb locally in the current directory
Env = {
    'ydb_xc_cstrlib': './cstrlib.xc',
    'ydb_routines': '. ' + os.environ['ydb_routines'],
#    'ydb_gbldir': 'tmp',
}


def user_time(user_func):
    """ Execute user_func and return user mode time spent doing so """
    usage_start = resource.getrusage(resource.RUSAGE_CHILDREN)
    user_func()
    usage_end = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu_time = usage_end.ru_utime - usage_start.ru_utime
    return cpu_time

def benchmark(mroutine, *args, repitions=10):
    """ Run mroutine from _benchmark.m repitions times and return the minimum time taken
        args = command line parameters passed to M routine
    """
    # set up environment so that dbase can run
    env = os.environ.copy()
    env.update(Env)
    func = lambda: subprocess.run(['gtm', '-run', mroutine+'^%benchmark'] + list(args), env=env)
    minimum = min(user_time(func) for _i in range(repitions))
    return minimum

def main():
    # Note: I tried to get rid of the init time compensation by making it neglegible,
    # but actually, most of it is ydb load time (~30ms) which we can't reduce
    init_time = benchmark('init')
    print(f"init: {init_time:0.3f}s")

    routines = OrderedDict(
        luaSHA = [dict(size=1_000_000, iter=1), dict(size=1_000, iter=500), dict(size=10, iter=500)],
    )
    if os.path.exists('cstrlib.so'):
        # Only add the following if cmumps was able to be installed
        routines.update(dict(
            cmumpsSHA = [dict(size=1_000_000, iter=100), dict(size=1_000, iter=50_000), dict(size=10, iter=50_000)],
        ))
    for routine, tests in routines.items():
        for test in tests:
            iterations = test['iter']
            size = test['size']
            result = benchmark('test', routine, str(iterations), str(size))
            per_iteration = (result-init_time) / iterations
            print(f"{per_iteration*1000000:6.0f}us {routine:>10s} {str(size)+' bytes':<13}  ({result-init_time:0.3f}s for {iterations} iterations -- {result:0.3f}s-init)")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print()
