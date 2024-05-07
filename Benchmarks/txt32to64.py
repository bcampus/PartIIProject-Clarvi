#!/usr/bin/env python

# Convert the Yarvi .txt format to Intel .hex

import sys

argc = len(sys.argv)
if argc != 3:
    sys.exit("Syntax: %s <infile> <outfile>" % sys.argv[0])

def txt32to64(infile, outfile):
    while True:
        l1 = infile.readline()
        if l1 == "":
            return
        l2 = infile.readline()[:-1]
        if l2 == "":
            outfile.write(8*"0" + l1)
            return
        outfile.write(l2+l1)
        

# allow "-" as the first argument meaning read from stdin
with (sys.stdin if sys.argv[1] == '-' else open(sys.argv[1], 'r')) as infile:
    with open(sys.argv[2], 'w') as outfile:
        txt32to64(infile, outfile)
