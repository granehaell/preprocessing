# this is just an example file of human preprocessing

#!/bin/bash
Forward=$1
Reverse=$2

PEAR.py $Forward $Reverse -min-len 25 -q 25 > merged.fq.gz

