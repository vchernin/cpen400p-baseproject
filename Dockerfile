# updated as of 2023-01-14, tag is only for human reference
FROM docker.io/ubuntu:18.04@sha256:0d32fa8d8671fb6600db45620b40e5189fc02eebb7e29fe8fbb0db49b58becea AS build

# things generally seem to assume stuff is dumped here because we are running as the root user
# todo user should probably not also be root but it doesn't really matter for this course
WORKDIR /root

COPY apt-dependencies.txt .

# image is already up to date so avoid upgrade, this step is obviously not reproducible since apt dependencies change
RUN apt-get update && \
# installing using bash and a seperate files for cleanness
/bin/bash -c "mapfile -t packs < apt-dependencies.txt && apt-get install --no-install-recommends -y \${packs[@]}" && \
# so we get man pages
yes | unminimize && \
# remove uncessary cache
rm -rf /var/lib/apt/lists/* && \
# get rid of now useless file, left in layer but that's ok
rm apt-dependencies.txt

# todo these should be versioned locked too
RUN pip3 install --no-cache-dir lit tabulate wllvm

# cmake

RUN wget --quiet https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1-linux-x86_64.tar.gz && \
tar -xzf cmake-3.22.1-linux-x86_64.tar.gz && \
# unfortunately the man pages dont copy due to the man link in /usr/local that seem to exist in ubuntu 18.04's image
rm cmake-3.22.1-linux-x86_64/man -r && \
cp -a cmake-3.22.1-linux-x86_64/. /usr/local/ && \
rm cmake-3.22.1-linux-x86_64.tar.gz cmake-3.22.1-linux-x86_64 -rf

# llvm

# do this in one monstrous step
# this is painful to debug since it needs to work all in one go,
# but it means we can clean up this layer properly, since even if you squash this at the end with a multi stage build,
# you still dont want a 15 GB docker layer getting cached every time you build this image

RUN git clone --branch release/13.x --depth 1 https://github.com/llvm/llvm-project.git && \
mkdir llvm-project/build && \ 
cd llvm-project/build && \
cmake -G Ninja ../llvm -DLLVM_ENABLE_PROJECTS="tools;clang;compiler-rt"  -DLLVM_TARGETS_TO_BUILD="host"  -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_OPTIMIZED_TABLEGEN=ON -DCMAKE_BUILD_TYPE=Release && \
ninja && \
ninja install && \
cd ../../ && \
# klee
# first install z3 provider
git clone --branch z3-4.12.0 --depth 1 https://github.com/Z3Prover/z3.git && \
mkdir z3/build && \
cd z3/build && \
cmake -G Ninja ../ && \
ninja && \
ninja install && \
# now prepare for z3 something
mkdir include && \
cp ../src/api/*.h ./include/ && \
cp ../src/api/c++/z3++.h ./include/z3++.h && \
cd ../../ && \
# now install KLEE and KLEE-uClibC:
git clone --branch klee_uclibc_v1.3 --depth 1 https://github.com/klee/klee-uclibc.git && \
cd klee-uclibc && \
./configure --make-llvm-lib && \
make KLEE_CFLAGS="-DKLEE_SYM_PRINTF" && \
cd .. && \
# before was --branch v2.3 and --depth 1
# checkout a more recent commit as that seems necessary
# todo try find a better approach
git clone https://github.com/klee/klee.git && \
cd klee && \
git checkout fc778afc9029c48b78aa59c20cdf3e8223a88081 && \
mkdir build && \
cd build && \
cmake -G Ninja -DENABLE_SOLVER_Z3=ON -DENABLE_UNIT_TESTS=OFF -DENABLE_SYSTEM_TESTS=OFF -DZ3_INCLUDE_DIRS=$HOME/z3/build/include -DENABLE_TCMALLOC=OFF -DHAVE_Z3_GET_ERROR_MSG_NEEDS_CONTEXT=ON -DENABLE_POSIX_RUNTIME=ON -DENABLE_KLEE_UCLIBC=ON -DKLEE_UCLIBC_PATH=$HOME/klee-uclibc -DLLVMCC=$HOME/llvm-project/build/bin/clang -DLLVMCXX=$HOME/llvm-project/build/bin/clang++ .. && \
ninja && \
ninja install && \
cd ../../ && \
rm llvm-project z3 klee-uclibc klee -rf

RUN git clone --branch 4.05c --depth 1 https://github.com/AFLplusplus/AFLplusplus.git && \
cd AFLplusplus && \
make distrib && \
make install && \
cd .. && \
rm AFLplusplus -rf

# this approach is clumsy due to apt deps as we have no way of knowing what apt deps we need at runtime
# FROM docker.io/ubuntu:18.04@sha256:0d32fa8d8671fb6600db45620b40e5189fc02eebb7e29fe8fbb0db49b58becea

# COPY --from=build /usr/local /usr/local

# put apt deps needed for actual development here as needed
