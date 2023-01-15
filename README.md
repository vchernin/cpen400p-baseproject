# Cpen 400p dependencies but better

Random misc changes:

python2-minimal from apt doesn't exist in ubuntu 18.04
ninja-build from apt is installed twice
llvm build instructions had needless cding
cmake install instructions used shell glob * instead of . which doesn't include hidden files
cmake installation instructions used cp -R instead of cp -a which preserves links which is usually wanted
changed a bunch of usage of cmake and make to cmake and ninja
removed any thread hardcoding, haven't seen any race conditions building this (sometimes llvm does but its rare and not worth losing the performance)
added zlib1g-dev to apt deps which is needed for klee
