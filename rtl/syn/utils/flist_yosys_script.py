#!/bin/env python3
# Copyright 2023 Commissariat a l'Energie Atomique et aux Energies
#                Alternatives (CEA)
# Copyright 2025 Inria
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Authors        Cesar Fuguet
# Date           June, 2025
# Description    Script to flatten a Flist file. Flattening consist on:
#                -  expanding environment variables in the file
#                -  expanding included Flist files

import sys;
import argparse;
import os;

def printYosysReadSystemVerilog(outf, file):
    outf.write(f'yosys read_slang -DHPDCACHE_ASSERT_OFF -DSYNTHESIS -DYOSYS {file}\n')


def printReadVerilog():
    outf.write(f'yosys read_verilog -DHPDCACHE_ASSERT_OFF -DSYNTHESIS -DYOSYS {file}\n')


def printLine(outf, line):
    if line.endswith('.sv'):
        printYosysReadSystemVerilog(outf, line)
    elif line.endswith('.v'):
        printYosysReadVerilog(outf, line)


def parseFlist(inFlist, outFlist, printIncdir, printNewline):
    lines = iter(inFlist.read().splitlines())
    for line in lines:
        line = line.strip()
        if (line.startswith('#') or
                line.startswith('//') or
                line.startswith('/*')):
            continue
        line = os.path.expandvars(line)
        if line.startswith('+incdir+'):
            if printIncdir:
                printLine(outFlist, line)
        elif line.startswith('-F'):
            includedFilename = line.lstrip('-F').strip()
            if not os.path.exists(includedFilename):
                raise (RuntimeError(f'{includedFilename} not found'))
            with open(includedFilename, 'r') as includedFlist:
                parseFlist(includedFlist, outFlist, printIncdir, printNewline)
        elif line:
            printLine(outFlist, line)


def getArguments():
    parser = argparse.ArgumentParser(description='Flatten a Flist file')
    parser.add_argument(
            '--print_incdir',
            action="store_true",
            help='Print incdir statements in the output')
    parser.add_argument(
            '--print_newline',
            action="store_true",
            help='Print newline in the output after each line')
    parser.add_argument(
            'inFlist',
            nargs='?',
            type=argparse.FileType('r'),
            default=sys.stdin,
            help='Input Flist file (default to stdin)')
    parser.add_argument(
            'outFlist',
            nargs='?',
            type=argparse.FileType('w'),
            default=sys.stdout,
            help='Output flattened Flist file (default to stdout)')
    return parser.parse_args()


if __name__ == "__main__":
    args = getArguments()
    parseFlist(args.inFlist, args.outFlist, args.print_incdir, args.print_newline)
