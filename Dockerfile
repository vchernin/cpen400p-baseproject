# updated as of 2023-01-14, tag is only for human reference
FROM docker.io/ubuntu:18.04@sha256:0d32fa8d8671fb6600db45620b40e5189fc02eebb7e29fe8fbb0db49b58becea AS build

# some of this file is rather annoying boilerplate copy paste, 
# but it's not worth rewriting in buildstream or something more abstract as arguably we should not build a lot of these things in the first place, and just rely on some newer distro instead. Why ubuntu 18.04?

# things generally seem to assume stuff is dumped here because we are running as the root user
# todo user should probably not also be root but it doesn't really matter for this course
WORKDIR /root

COPY apt-dependencies.txt requirements.txt ./

# image is already up to date so avoid upgrade, this step is obviously not reproducible since apt dependencies change
RUN apt-get update && \
# installing using bash and a seperate files for cleanness
/bin/bash -c "mapfile -t packs < apt-dependencies.txt && apt-get install --no-install-recommends -y \${packs[@]}" && \
# so we get man pages
yes | unminimize && \
# remove uncessary cache
rm -rf /var/lib/apt/lists/* && \
# get rid of now useless file, left in layer but that's ok since it's small
rm apt-dependencies.txt

RUN pip3 install --require-hashes --only-binary :all: --no-cache-dir -r requirements.txt && \
# get rid of now useless file, left in layer but that's ok since it's small
rm requirements.txt

# cmake

RUN curl -LO https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1-linux-x86_64.tar.gz && \
echo "73565c72355c6652e9db149249af36bcab44d9d478c5546fd926e69ad6b43640 cmake-3.22.1-linux-x86_64.tar.gz" > SHA256SUMS.txt && \
sha256sum -c SHA256SUMS.txt && \
tar -xzf cmake-3.22.1-linux-x86_64.tar.gz && \
mv cmake-3.22.1-linux-x86_64 cmake && \
# unfortunately the man pages dont copy due to the man link in /usr/local that seem to exist in ubuntu 18.04's image
rm cmake/man -r && \
cp -a cmake/. /usr/local/ && \
rm *.tar.gz cmake SHA256SUMS.txt -rf

# llvm

# do this in one monstrous step
# this is painful to debug since it needs to work all in one go,
# but it means we can clean up this layer properly, since even if you squash this at the end with a multi stage build,
# you still dont want a 15 GB docker layer getting cached every time you build this image

# use a file of sha256sums since it is a bit more robust and faster than git cloning  (llvm is only a 140 MB tar versus the massive download size even with shallow cloning)
# even with a shallow clone git clone allows us to specify a branch/tag when cloning, but a branch and tag can have the same name so its not very fool proof
COPY SHA256SUMS.txt ./

RUN curl -LO https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-13.0.1.tar.gz && \
curl -LO https://github.com/Z3Prover/z3/archive/refs/tags/z3-4.12.0.tar.gz && \
curl -LO https://github.com/klee/klee-uclibc/archive/refs/tags/klee_uclibc_v1.3.tar.gz && \
# originally tried using tag v2.3
# checkout a more recent commit as that seems necessary
# todo try find a better approach
curl -LO https://github.com/klee/klee/archive/fc778afc9029c48b78aa59c20cdf3e8223a88081.tar.gz && \
sha256sum -c SHA256SUMS.txt && \
# unarchive everything, and then rename so file names are more consistent
tar -xzf llvmorg-13.0.1.tar.gz && \
mv llvm-project-llvmorg-13.0.1 llvm-project && \
tar -xzf z3-4.12.0.tar.gz && \
mv z3-z3-4.12.0 z3 && \
tar -xzf klee_uclibc_v1.3.tar.gz && \
mv klee-uclibc-klee_uclibc_v1.3 klee-uclibc && \
tar -xzf fc778afc9029c48b78aa59c20cdf3e8223a88081.tar.gz && \
mv klee-fc778afc9029c48b78aa59c20cdf3e8223a88081 klee && \
# llvm
mkdir llvm-project/build && \ 
cd llvm-project/build && \
cmake -G Ninja ../llvm -DLLVM_ENABLE_PROJECTS="tools;clang;compiler-rt;lld"  -DLLVM_TARGETS_TO_BUILD="host"  -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_ENABLE_RTTI=ON -DLLVM_OPTIMIZED_TABLEGEN=ON -DCMAKE_BUILD_TYPE=Release && \
ninja && \
ninja install && \
cd ../../ && \
# klee
# first install z3 prover
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
cd klee-uclibc && \
./configure --make-llvm-lib && \
make KLEE_CFLAGS="-DKLEE_SYM_PRINTF" && \
cd .. && \
cd klee && \
mkdir build && \
cd build && \
cmake -G Ninja -DENABLE_SOLVER_Z3=ON -DENABLE_UNIT_TESTS=OFF -DENABLE_SYSTEM_TESTS=OFF -DZ3_INCLUDE_DIRS=$HOME/z3/build/include -DENABLE_TCMALLOC=OFF -DHAVE_Z3_GET_ERROR_MSG_NEEDS_CONTEXT=ON -DENABLE_POSIX_RUNTIME=ON -DENABLE_KLEE_UCLIBC=ON -DKLEE_UCLIBC_PATH=$HOME/klee-uclibc -DLLVMCC=$HOME/llvm-project/build/bin/clang -DLLVMCXX=$HOME/llvm-project/build/bin/clang++ .. && \
ninja && \
ninja install && \
cd ../../ && \
rm *.tar.gz llvm-project z3 klee-uclibc klee SHA256SUMS.txt -rf

RUN curl -LO https://github.com/AFLplusplus/AFLplusplus/archive/refs/tags/4.05c.tar.gz && \
echo "5a2a7e94690771e2d80d2b30a72352e16bcc14f2cfff6d6fc1fd67f0ce2a9d3b 4.05c.tar.gz" > SHA256SUMS.txt && \
sha256sum -c SHA256SUMS.txt && \
tar -xzf 4.05c.tar.gz && \
mv AFLplusplus-4.05c AFLplusplus && \
cd AFLplusplus && \
make distrib && \
make install && \
cd .. && \
rm *.tar.gz AFLplusplus SHA256SUMS.txt -rf

# mold (depends on newer clang so build it after llvm)
# build openssl and install extra stdlib headers following https://github.com/rui314/mold/blob/ec756333cbfdb02dc96a4aebf9f8a9b374a4b5a7/common/Dockerfile
RUN curl -LO https://www.openssl.org/source/openssl-3.0.7.tar.gz && \
echo "83049d042a260e696f62406ac5c08bf706fd84383f945cf21bd61e9ed95c396e openssl-3.0.7.tar.gz" > SHA256SUMS.txt && \
sha256sum -c SHA256SUMS.txt && \
tar -xzf openssl-3.0.7.tar.gz && \
mv openssl-3.0.7 openssl && \
cd openssl && \
./Configure --prefix=/usr/local --libdir=lib && \
make -j$(nproc) && \
make -j$(nproc) install && \
ldconfig && \
cd .. && \
rm *.tar.gz openssl SHA256SUMS.txt -rf

RUN apt-get update && \
  apt-get install -y --no-install-recommends software-properties-common && \
  add-apt-repository -y ppa:ubuntu-toolchain-r/test && \
  apt-get update && \
  apt-get install -y --no-install-recommends libstdc++-11-dev && \
  rm -rf /var/lib/apt/lists/*

RUN curl -LO https://github.com/rui314/mold/archive/refs/tags/v1.10.1.tar.gz && \
echo "19e4aa16b249b7e6d2e0897aa1843a048a0780f5c76d8d7e643ab3a4be1e4787 v1.10.1.tar.gz" > SHA256SUMS.txt && \
sha256sum -c SHA256SUMS.txt && \
tar -xzf v1.10.1.tar.gz && \
mv mold-1.10.1 mold && \
mkdir mold/build && \
cd mold/build && \
cmake -G Ninja ../ -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=clang++ && \
ninja && \
ninja install && \
cd ../../ && \
rm *.tar.gz mold SHA256SUMS.txt -rf

# disable fish greeting
RUN mkdir -p /root/.config/fish/
RUN echo "set fish_greeting" >> /root/.config/fish/config.fish

# this approach is clumsy due to apt deps as we have no way of knowing what apt deps we need at runtime
# FROM docker.io/ubuntu:18.04@sha256:0d32fa8d8671fb6600db45620b40e5189fc02eebb7e29fe8fbb0db49b58becea

# COPY --from=build /usr/local /usr/local

# put apt deps needed for actual development here as needed
