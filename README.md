# docker-shader

Docker image with a range of shader compilers available

Hub: https://hub.docker.com/r/gwihlidal/docker-shader/

## Extensive documentation:

- https://www.wihlidal.com/blog/pipeline/2018-09-15-linux-dxc-docker/
- https://www.wihlidal.com/blog/pipeline/2018-09-16-dxil-signing-post-compile/
- https://www.wihlidal.com/blog/pipeline/2018-09-17-linux-fxc-docker/
- https://www.wihlidal.com/blog/pipeline/2018-12-28-containerized-shader-compilers/

## Updating Compilers:

The latest commit hashes can be queried using the following script:

```bash
$ ./query_latest.sh
Latest DXC_COMMIT
a6189cee038b9e91ebb22b2305367a66aa001413

Latest SHADERC_REPO
b3523d57461c1460af68dbd6bec1e8dd5c7ce2e7

Latest WINE_REPO
cce8074aa9fb2191faba25ce7fd24e2678d3bd17

Latest SMOLV_REPO
ce2835a03fc17df4c08ae6433db02121e29f3c71
```

These hashes can replace the older commit hashes in `Dockerfile`.

To upgrade the Vulkan SDK, find the latest version number at https://vulkan.lunarg.com/ and set the `VULKAN_SDK` environment variable accordingly.

Before building and pushing a new image, increment the version number at the top of `Makefile`

Build and push a new image by running `make push`, or by running the commands manually (substituting in the correct variable values):

```bash
docker build -t $(NS)/$(REPO):$(VERSION) .
docker push $(NS)/$(REPO):$(VERSION)
```

Example:

```bash
docker build -t gwihlidal/docker-shader:9 .
docker push gwihlidal/docker-shader:9
```

Note, you won't have permission to push to the `gwihlidal` namespace on Docker Hub, so make sure to use your own account or custom container registry like https://cloud.google.com/container-registry/

Example of a version update:

https://github.com/gwihlidal/docker-shader/commit/b1231046b7509400da4f4ffeba8743e76d8bfc4c
