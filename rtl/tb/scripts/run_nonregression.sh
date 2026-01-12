#!/bin/bash
##
#  Copyright 2023,2024 Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
#  Copyright 2025 Univ. Grenoble Alpes, Inria, TIMA Laboratory
#
#  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
##
#  Author     : Cesar Fuguet
#  Date       : December, 2025
#  Description: nonregression script
##
sequence=random
ntests=32
ntrans=30000
logdir=nonreg
loglevel=1
config=configs/default_config.mk
coverage=0

help() {
    echo "help: $0"
    echo "      -s <sequence>        desc: name of the test sequence to execute (default: ${ntrans})"
    echo "      -n <ntests>          desc: number of tests to execute (default: ${ntests})"
    echo "      -t <ntrans>          desc: number of transactions (default: ${ntrans})"
    echo "      -l <logdir>          desc: logs directory (default: ${logdir})"
    echo "      -c <config>          desc: config file (default: ${config})"
    echo "      -d <loglevel>        desc: logging level (default: ${loglevel})"
    echo "      -e <coverage>        desc: coverage (default: ${coverage})"
    echo "      -h                   desc: show this help message"
}

while [[ $# -gt 0 ]] ; do
    case $1 in
        -s)
            sequence=$2
            shift 2 ;;
        -n)
            ntests=$2
            shift 2 ;;
        -t)
            ntrans=$2
            shift 2 ;;
        -l)
            logdir=$2
            shift 2 ;;
        -c)
            config=$2
            shift 2 ;;
        -j)
            njobs=$2
            shift 2 ;;
        -d)
            loglevel=$2
            shift 2 ;;
        -e)
            coverage=$2
            shift 2 ;;
        -h)
            help
            exit 1 ;;
    esac
done

echo "Running non-regression testsuite with SEQUENCE=${sequence}"

i=1
mkdir -p ${logdir}
for s in $(head -n ${ntests} scripts/random_numbers.dat | tr '\n' ' ') ; do
    echo "[$i/${ntests}] Running sequence ${sequence} SEED=${s}" ; ((i++)) ;
    make -s run SEQUENCE=${sequence} SEED=${s} NTRANSACTIONS=${ntrans} \
            RUN_LOG=${logdir}/${sequence}_${s}.log LOG_LEVEL=${loglevel} \
            COV=${coverage};
done

PERL5LIB=./scripts/perl5 \
./scripts/scan_logs.pl -listwarnings -listerrors \
    -pat scripts/scan_patterns/run_patterns.pat \
    -att scripts/scan_patterns/run_attributes.pat \
    -nowarn ${logdir}/${sequence}_*.log \
    2>&1 | tee ${logdir}/${sequence}_nonreg.log.scan ;

exit ${PIPESTATUS[0]}
