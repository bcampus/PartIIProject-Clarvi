for b in rv64-modularise rv64-32-modularise rv64-16-modular rv64-8-modular; do
    echo $b;
    echo;
    git checkout -q $b;
    for f in nsum bubble mult primes; 
    do
        echo -n "$f: ";
        vsim -c -do "do ./benchmark.tcl $f" | grep -oh "Time: [0-9]* ns";
    done;
    echo;
done;
