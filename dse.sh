#!/bin/sh

#Takes as parameters: number to generate and destination folder

qsys-generate -synthesis=verilog clarvi_soc.qsys

quartus_dse clarvi_fpga \
    --num-seeds $1 \
    --launcher local \
    --num-concurrent 10

cp -r ./dse/* $2
