# https://www.wihlidal.com/blog/pipeline/2018-09-15-linux-dxc-docker/
# https://www.wihlidal.com/blog/pipeline/2018-09-16-dxil-signing-post-compile/
# https://www.wihlidal.com/blog/pipeline/2018-09-17-linux-fxc-docker/

FROM ubuntu:18.04 as builder

ENV DXC_BRANCH=master
ENV DXC_REPO=https://github.com/Microsoft/DirectXShaderCompiler.git
ENV DXC_COMMIT=cd237f5c3f7e8390fafff122333423afe55bc6c7

ENV SHADERC_BRANCH=master
ENV SHADERC_REPO=https://github.com/google/shaderc.git
ENV SHADERC_COMMIT=53c776f776821bc037b31b8b3b79db2fa54b4ce7

ENV GOOGLE_TEST_BRANCH=master
ENV GOOGLE_TEST_REPO=https://github.com/google/googletest.git
ENV GOOGLE_TEST_COMMIT=c6cb7e033591528a5fe2c63157a0d8ce927740dc

ENV GLSLANG_BRANCH=master
ENV GLSLANG_REPO=https://github.com/google/glslang.git
ENV GLSLANG_COMMIT=667506a5eae80931290c2f424888cc5f52fec5d1

ENV SPV_TOOLS_BRANCH=master
ENV SPV_TOOLS_REPO=https://github.com/KhronosGroup/SPIRV-Tools.git
ENV SPV_TOOLS_COMMIT=c512c6864080ff617afb422a3d04dd902809a6cf

ENV SPV_HEADERS_BRANCH=master
ENV SPV_HEADERS_REPO=https://github.com/KhronosGroup/SPIRV-Headers.git
ENV SPV_HEADERS_COMMIT=17da9f8231f78cf519b4958c2229463a63ead9e2

ENV RE2_BRANCH=master
ENV RE2_REPO=https://github.com/google/re2.git
ENV RE2_COMMIT=fadc34500b67414df452c54d980372242f3d7f57

ENV EFFCEE_BRANCH=master
ENV EFFCEE_REPO=https://github.com/google/effcee.git
ENV EFFCEE_COMMIT=8f0a61dc95e0df18c18e0ac56d83b3fa9d2fe90b

ENV WINE_BRANCH=dxil
ENV WINE_REPO=https://github.com/gwihlidal/wine.git
ENV WINE_COMMIT=d2847c40d93a4a6d53f243b9c09ee582015b5ff4

ENV SMOLV_BRANCH=master
ENV SMOLV_REPO=https://github.com/aras-p/smol-v.git
ENV SMOLV_COMMIT=9a787d1354a9e43c9ea6027cd310ce2a2fd78901

ENV VULKAN_SDK=1.1.92.1

# Prevents annoying debconf errors during builds
ARG DEBIAN_FRONTEND="noninteractive"

# Download libraries and tools
RUN apt-get update && \
	apt-get install -y \
		software-properties-common \
		build-essential \
		git \
		cmake \
		ninja-build \
		python \
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

# Download and build DXC
RUN git clone --recurse-submodules -b ${DXC_BRANCH} ${DXC_REPO} /dxc && cd /dxc \
	git checkout ${DXC_COMMIT} && \
	git reset --hard && \
	mkdir -p /dxc/build && cd /dxc/build && \
	cmake ../ -GNinja -DCMAKE_BUILD_TYPE=Release $(cat ../utils/cmake-predefined-config-params) && \
	ninja

# Download shaderc repository and dependencies
RUN git clone --recurse-submodules -b ${SHADERC_BRANCH} ${SHADERC_REPO} /shaderc && cd /shaderc \
	git checkout ${SHADERC_COMMIT} && git reset --hard && \
	mkdir -p /shaderc/third_party && cd /shaderc/third_party && \
	#
	git clone --recurse-submodules -b ${GOOGLE_TEST_BRANCH} ${GOOGLE_TEST_REPO} googletest && \
	cd googletest && git checkout ${GOOGLE_TEST_COMMIT} && git reset --hard && cd .. && \
	#
	git clone --recurse-submodules -b ${GLSLANG_BRANCH} ${GLSLANG_REPO} glslang && \
	cd glslang && git checkout ${GLSLANG_COMMIT} && git reset --hard && cd .. && \
	#
	git clone --recurse-submodules -b ${SPV_TOOLS_BRANCH} ${SPV_TOOLS_REPO} spirv-tools && \
	cd spirv-tools && git checkout ${SPV_TOOLS_COMMIT} && git reset --hard && cd .. && \
	#
	git clone --recurse-submodules -b ${SPV_HEADERS_BRANCH} ${SPV_HEADERS_REPO} spirv-headers && \
	cd spirv-headers && git checkout ${SPV_HEADERS_COMMIT} && git reset --hard && cd .. && \
	#
	git clone --recurse-submodules -b ${RE2_BRANCH} ${RE2_REPO} re2 && \
	cd re2 && git checkout ${RE2_COMMIT} && git reset --hard && cd .. && \
	#
	git clone --recurse-submodules -b ${EFFCEE_BRANCH} ${EFFCEE_REPO} effcee && \
	cd effcee && git checkout ${EFFCEE_COMMIT} && git reset --hard && cd ..

# Build shaderc
RUN mkdir -p /shaderc/build && cd /shaderc/build && \
	cmake -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    .. && \
	ninja install

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

# Download and extract signing tool
WORKDIR /
RUN wget -O signing.zip https://github.com/gwihlidal/dxil-signing/releases/download/0.1.2/dxil-signing-0_1_2.zip && \
	unzip -q signing.zip; exit 0
RUN mv dxil-signing-0_1_2 signing

# Download and extract Linux and Windows binaries of AMD RGA
WORKDIR /rga
RUN wget -O rga_linux.tgz https://github.com/GPUOpen-Tools/RGA/releases/download/2.0.1/rga-linux-2.0.1.tgz && \
	tar zxf rga_linux.tgz && \
	mv rga-2.0.1.* linux && \
	rm rga_linux.tgz && \
	wget -O rga_windows.zip https://github.com/GPUOpen-Tools/RGA/releases/download/2.0.1/rga-windows-x64-2.0.1.zip && \
	unzip -q rga_windows.zip; exit 0
RUN mv bin windows && \
	# Remove GUI binaries
	rm -f /rga/rga_windows.zip && \
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
FROM ubuntu:18.04

# Apply updates
RUN apt update \
	&& apt install -y \
		# Required for Wine
		libpng-dev \
	# Clean up
	&& apt autoremove -y \
	&& apt autoclean \
	&& apt clean \
	&& apt autoremove

# Copy DXC binaries from `builder` stage into final stage
WORKDIR /app/dxc
COPY --from=builder /dxc/build/bin/dxc /app/dxc/bin/dxc
COPY --from=builder /dxc/build/lib/libdxcompiler.so.3.7 /app/dxc/lib/libdxcompiler.so.3.7
RUN ln -s /dxc/lib/libdxcompiler.so.3.7 /app/dxc/lib/libdxcompiler.so

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
ENV SIGN_PATH="/app/signing/dxil-signing.exe"
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