# Cpen 400p dependencies but better



### Download

First get a PAT for your github account that has access to this repo (could be avoided if this repo was public)

```
export CR_PAT=YOUR_TOKEN
echo $CR_PAT | podman login ghcr.io -u USERNAME --password-stdin
podman pull ghcr.io/vchernin/cpen400p-baseproject:latest
```

[Full documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

### Build

Not recommended unless you have many threads due to needing to compile LLVM and a few other things

```sh
podman build -t ghcr.io/vchernin/cpen400p-baseproject .
```

#### Random misc changes:

python2-minimal from apt doesn't exist in ubuntu 18.04
ninja-build from apt was listed twice
llvm build instructions had needless cding
cmake install instructions used shell glob * instead of . which doesn't include hidden files
cmake installation instructions used cp -R instead of cp -a which preserves links which is usually wanted
changed a bunch of usage of cmake and make to cmake and ninja
removed any thread hardcoding, haven't seen any race conditions building this (sometimes llvm seems to but its rare and not worth losing the performance)
added zlib1g-dev to apt deps which is needed for klee
