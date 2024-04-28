#!/usr/bin/env python

# Convert the Yarvi .txt format to Intel .hex

import sys

argc = len(sys.argv)
if argc != 3:
    sys.exit("Syntax: %s <infile> <outfile>" % sys.argv[0])

def txt32to8(infile, outfile):
    while True:
        l1 = infile.readline()
        if l1 == "":
            return
        outfile.write(l1[6:])
        outfile.write(l1[4:6]+ '\n')
        outfile.write(l1[2:4]+ '\n')
        outfile.write(l1[:2] + '\n')
        

# allow "-" as the first argument meaning read from stdin
with (sys.stdin if sys.argv[1] == '-' else open(sys.argv[1], 'r')) as infile:
    with open(sys.argv[2], 'w') as outfile:
        txt32to8(infile, outfile)
