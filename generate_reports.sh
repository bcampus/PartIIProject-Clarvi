#!/bin/bash

for b in rv64-modularise rv64-32-modularise rv64-16-modular rv64-8-modular; do
    echo ; echo;
    echo "=============== MOVING TO $b ===============";
    echo ; echo;
    
    git checkout $b;
    ./dse.sh $1 ./report_gen/$b;
    cd ./report_gen/$b/;
    for (( i=1; i<=$1; i+=1 ))
    do
        echo $i;
        cd ./dse1_clarvi_fpga_$i/;
        quartus_sh -t ../../../UtilReport.tcl -file ../../$b-$i.csv
        cd ../;
    done;
    cd ../../
done;
