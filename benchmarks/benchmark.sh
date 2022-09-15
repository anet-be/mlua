#!/bin/bash

export ydb_xc_cstrlib=cstrlib.xc
export ydb_routines=". $ydb_routines"

# Parameter specifies how many times to repeat each timing test to get an average
iterations=1
[[ "$1" != "" ]] && iterations="$1"

# use external time command, not internal bash one
time="$(which time)"

benchmark() {
    name="$1"
    shift
    echo -n >"$name".time
    for i in $(seq $iterations); do
        $time -f %U -a -o "$name".time  "$@"
    done
    result=$( awk '{s+=$1} END {print s/NR} ' RS=' ' "$name".time )
    echo "$name: ${result}s"
}

# calculate init time
benchmark init  gtm -run init^%shaBench
benchmark cmumps  gtm -run run^%shaBench

#benchmark cmumps  gtm -run cmumps^%shaBench

rm *.time
