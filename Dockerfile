# https://www.wihlidal.com/blog/pipeline/2018-09-15-linux-dxc-docker/
# https://www.wihlidal.com/blog/pipeline/2018-09-16-dxil-signing-post-compile/
# https://www.wihlidal.com/blog/pipeline/2018-09-17-linux-fxc-docker/
# https://www.wihlidal.com/blog/pipeline/2018-12-28-containerized_shader_compilers/

FROM ubuntu:bionic as builder

ENV DXC_BRANCH=master
ENV DXC_REPO=https://github.com/gwihlidal/DirectXShaderCompiler.git
ENV DXC_COMMIT=a117e417f18d7ab829abc5c6903416f7bd0b2183

ENV SHADERC_BRANCH=master
ENV SHADERC_REPO=https://github.com/google/shaderc.git
ENV SHADERC_COMMIT=6805e5544d6c3733e941754376f44d0d5b61309f

ENV WINE_BRANCH=master
ENV WINE_REPO=https://github.com/wine-mirror/wine.git
ENV WINE_COMMIT=6e3f39a4c59fd529c7b532dcde1bb8c37c467b35

ENV SMOLV_BRANCH=master
ENV SMOLV_REPO=https://github.com/aras-p/smol-v.git
ENV SMOLV_COMMIT=9a787d1354a9e43c9ea6027cd310ce2a2fd78901

ENV VULKAN_SDK=1.1.106.0

# Prevents annoying debconf errors during builds
ARG DEBIAN_FRONTEND="noninteractive"

# Download libraries and tools
RUN apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y \
		software-properties-common \
		build-essential \
		locales \
		git \
		cmake \
		ninja-build \
		python \
		python3-dev \
		python3-pip \
		wget \
		unzip \
		# Required for Wine
		flex \
		bison \
		libpng-dev \
		# Required for Vulkan
		libwayland-dev \
		libx11-dev \
		libxrandr-dev \
	# Clean up
	&& apt autoremove -y \
		software-properties-common \
	&& apt autoclean \
	&& apt clean \
	&& apt autoremove

# Download shaderc repository and dependencies
RUN git clone --recurse-submodules -b ${SHADERC_BRANCH} ${SHADERC_REPO} /shaderc && cd /shaderc \
	git checkout ${SHADERC_COMMIT} && git reset --hard && \
	python3 ./utils/git-sync-deps

# Set the locale (needed for python3 and shaderc build scripts)
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
	dpkg-reconfigure --frontend=noninteractive locales && \
	update-locale LANG=en_US.UTF-8
ENV LANG en_US.UTF-8 

# Build shaderc
RUN mkdir -p /shaderc/build && cd /shaderc/build && \
	cmake -GNinja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=/usr/local \
	-DSHADERC_SKIP_TESTS=ON \
	-DSPIRV_SKIP_TESTS=ON \
	.. && \
	ninja install

# Download and build Vulkan SDK
WORKDIR /
RUN wget -O vulkan.tgz https://sdk.lunarg.com/sdk/download/${VULKAN_SDK}/linux/vulkansdk-linux-x86_64-${VULKAN_SDK}.tar.gz && \
	tar zxf vulkan.tgz && \
	mv ${VULKAN_SDK} vulkan && \
	rm vulkan.tgz && \
	cd /vulkan && \
	chmod +x setup-env.sh && \
	chmod +x build_tools.sh && \
	./setup-env.sh && ./build_tools.sh

# Download and build SMOL-V
WORKDIR /smol-v
RUN git clone --recurse-submodules -b ${SMOLV_BRANCH} ${SMOLV_REPO} /app/smol-v && cd /app/smol-v && \
	git checkout ${SMOLV_COMMIT} && git reset --hard && \
	make -f projects/Makefile -j 4

# Download and install Wine (for running FXC, DXIL signing tool, RGA for Windows)
WORKDIR /wine_src
RUN git clone --recurse-submodules -b ${WINE_BRANCH} ${WINE_REPO} /wine_src && \
	git checkout ${WINE_COMMIT} && \
	git reset --hard && \
	./configure --enable-win64 --with-png --without-freetype --without-x --prefix=/wine && \
	make -j8 && \
	make install

# Download and build DXC
RUN git clone --recurse-submodules -b ${DXC_BRANCH} ${DXC_REPO} /dxc && cd /dxc \
	git checkout ${DXC_COMMIT} && \
	git reset --hard && \
	mkdir -p /dxc/build && cd /dxc/build && \
	cmake ../ -GNinja -DCMAKE_BUILD_TYPE=Release $(cat ../utils/cmake-predefined-config-params) && \
	ninja

# Download and extract signing tool
WORKDIR /signing
RUN wget -O signing.zip https://github.com/gwihlidal/dxil-signing/releases/download/0.1.4/dxil-signing-0_1_4.zip --no-check-certificate && \
	unzip -q signing.zip; exit 0
RUN rm signing.zip

# Download and extract Linux and Windows binaries of AMD RGA
WORKDIR /rga
RUN wget -O rga_linux.tgz https://github.com/GPUOpen-Tools/RGA/releases/download/2.1/rga-linux-2.1.tgz --no-check-certificate && \
	tar zxf rga_linux.tgz && \
	mv rga-2.1.* linux && \
	rm rga_linux.tgz

WORKDIR /rga/windows
RUN wget -O rga_windows.zip https://github.com/GPUOpen-Tools/RGA/releases/download/2.1/rga-windows-x64-2.1.zip --no-check-certificate && \
	unzip -q rga_windows.zip; exit 0

# Remove GUI binaries
RUN rm -f /rga/windows/rga_windows.zip && \
	rm -f /rga/windows/Qt* && \
	rm -f /rga/windows/RadeonGPUAnalyzerGUI.exe && \
	rm -fr /rga/windows/iconengines && \
	rm -fr /rga/windows/imageformats && \
	rm -fr /rga/windows/platforms && \
	rm -fr /rga/linux/Qt && \
	rm -fr /rga/linux/Documentation && \
	rm -f /rga/linux/RadeonGPUAnalyzerGUI-bin && \
	rm -f /rga/linux/RadeonGPUAnalyzerGUI

# Start from a new image
FROM ubuntu:bionic

# Apply updates
RUN apt update && \
	apt install --no-install-recommends -y  \
		# Required for Wine
		libpng-dev \
	# Clean up
	&& apt clean \
	&& apt autoremove

# Copy DXC binaries from `builder` stage into final stage
WORKDIR /app/dxc
COPY --from=builder /dxc/build/bin/dxc-3.7 /app/dxc/bin/dxc-3.7
COPY --from=builder /dxc/build/lib/libdxcompiler.so.3.7 /app/dxc/lib/libdxcompiler.so.3.7
RUN ln -s /app/dxc/bin/dxc-3.7 /app/dxc/bin/dxc
RUN ln -s /app/dxc/lib/libdxcompiler.so.3.7 /app/dxc/lib/libdxcompiler.so

# Copy glslc binary from `builder` stage into final stage
WORKDIR /app/shaderc
COPY --from=builder /shaderc/build/glslc/glslc /app/shaderc/glslc

# Copy SMOL-V binaries from `builder` stage into final stage
WORKDIR /app/smol-v
COPY --from=builder /app/smol-v /app/smol-v

# Copy Vulkan install binaries from `builder` stage into final stage
WORKDIR /app/vulkan
COPY --from=builder /vulkan/x86_64/bin /app/vulkan

# Copy Wine install from `builder` stage into final stage
WORKDIR /app/wine
COPY --from=builder /wine /app/wine

# Copy DXIL signing binaries from `builder` stage into final stage
WORKDIR /app/signing
COPY --from=builder /signing /app/signing

# Copy RGA binaries from `builder` stage into final stage
WORKDIR /app/rga
COPY --from=builder /rga /app/rga

# Copy local FXC binaries into container
WORKDIR /app/fxc
COPY fxc_bin /app/fxc

# Convenient path variables
ENV DXC_PATH="/app/dxc/bin/dxc"
ENV FXC_PATH="/app/fxc/fxc.exe"
ENV SIGN_PATH="/app/signing/dxil-val.exe"
ENV RGA_WIN_PATH="/app/rga/windows/rga.exe"
ENV RGA_NIX_PATH="/app/rga/linux/rga"
ENV GLSLC_PATH="/app/shaderc/glslc"
ENV SMOLV_PATH="/app/smol-v/smolv"
ENV WINE_PATH="/app/wine/bin/wine64"
ENV VULKAN_PATH="/app/vulkan"

# Configuration of Wine
ENV WINEARCH=win64
ENV WINEDEBUG=fixme-all
RUN /app/wine/bin/winecfg

WORKDIR /app
ENTRYPOINT ["/bin/bash"]