# Cpen 400p dependencies but better

This is a podman/docker setup for cpen 400p. This should theoretically be equiavalent to the provided virtualbox image.

If using `docker` replace `podman` with `docker` in the below commands

### Pull image

First get a PAT for your github account that has access to this repo (could be avoided if this repo was public)

```
export CR_PAT=YOUR_TOKEN
echo $CR_PAT | podman login ghcr.io -u USERNAME --password-stdin
podman pull ghcr.io/vchernin/cpen400p-baseproject:latest
```

[Full documentation about github container registry usage](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

### Using Container

Note for practical usage you would probably want to mount your own working directory into the container (say your local llvm git repo). There are no git repos in this container, just prebuilt binaries and libraries.

```
podman run -it --rm cpen400p-baseproject
```

### Build

Not recommended unless you have many threads due to needing to compile LLVM and a few other things

```sh
podman build -t ghcr.io/vchernin/cpen400p-baseproject .
```

### Misc changes from original instructions:

- python2-minimal from apt doesn't exist in ubuntu 18.04 so remove it
- ninja-build from apt was listed twice
- llvm build instructions had needless cding
- cmake install instructions used shell glob * instead of . which doesn't include hidden files
- cmake installation instructions used cp -R instead of cp -a which preserves links which is usually wanted
- changed a bunch of usage of cmake and make to cmake and ninja
- removed any thread count hardcoding, haven't seen any race conditions building this (sometimes llvm seems to but its rare and not worth losing the performance)
- added zlib1g-dev to apt deps which is needed for klee
