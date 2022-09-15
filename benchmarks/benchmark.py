#!/usr/bin/env python3

import os
import subprocess
import resource

def user_time(user_func):
    """ Execute user_func and return user mode time spent doing so """
    usage_start = resource.getrusage(resource.RUSAGE_CHILDREN)
    user_func()
    usage_end = resource.getrusage(resource.RUSAGE_CHILDREN)
    cpu_time = usage_end.ru_utime - usage_start.ru_utime
    return cpu_time

def benchmark(mroutine, iterations=10):
    """ Run mroutine from _benchmark.m iterations times and return the minimum time """
    # set up environment so that dbase can run
    env = os.environ.copy()
    env['ydb_xc_cstrlib'] = './cstrlib.xc'
    env['ydb_routines'] = '. ' + env['ydb_routines']
    func = lambda: subprocess.run(['gtm', '-run', mroutine+'^%benchmark'], env=env)
    minimum = min(user_time(func) for _i in range(iterations))
    return minimum

def main():
    init_time = benchmark('init')
    print(f"init: {init_time:0.3f}s")

    routines = ['cmumpsLong', 'cmumpsMed', 'cmumpsSmall']
    for r in routines:
        result = benchmark(r)
        print(f"{r}: {result-init_time:0.3f}s ({result:0.3f}s-init)")

if __name__ == '__main__':
    main()
