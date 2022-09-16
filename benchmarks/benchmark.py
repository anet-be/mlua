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
        'lua': [dict(iter=100, size=1_000_000), dict(iter=50_000, size=1_000), dict(iter=50_000, size=10)]
    )
    if os.path.exists('cstrlib.so'):
        # Only add the following if cmumps was able to be installed
        routines.update({
            'cmumps': [dict(iter=100, size=1_000_000), dict(iter=50_000, size=1_000), dict(iter=50_000, size=10)]
        })
    for routine, tests in routines.items():
        for test in tests:
            iterations = str(test['iter'])
            size = str(test['size'])
            result = benchmark('test', routine, iterations, size)
            print(f"{routine} x{iterations} size {size}: {result-init_time:0.3f}s ({result:0.3f}s-init)")

if __name__ == '__main__':
    main()
