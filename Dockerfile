# https://www.wihlidal.com/blog/pipeline/2018-09-15-linux-dxc-docker/
FROM ubuntu:18.04 as dxc_builder
ENV DXC_BRANCH=master
ENV DXC_REPO=https://github.com/Microsoft/DirectXShaderCompiler.git
ENV DXC_COMMIT=cd237f5c3f7e8390fafff122333423afe55bc6c7
WORKDIR /dxc
RUN apt-get update && \
	apt-get install -y \
	software-properties-common \
	build-essential \
	git \
	cmake \
	ninja-build \
	python
RUN git clone --recurse-submodules -b ${DXC_BRANCH} ${DXC_REPO} /dxc && \
	git checkout ${DXC_COMMIT} && \
	git reset --hard
RUN mkdir -p /dxc/build && cd /dxc/build && \
	cmake ../ -GNinja -DCMAKE_BUILD_TYPE=Release $(cat ../utils/cmake-predefined-config-params) && \
	ninja

# https://www.wihlidal.com/blog/pipeline/2018-09-17-linux-fxc-docker/
FROM ubuntu:18.04
# Prevents annoying debconf errors during builds
ARG DEBIAN_FRONTEND="noninteractive"
RUN dpkg --add-architecture i386 \
	&& apt update \
	&& apt install -y \
		# Required for adding and building repositories
		software-properties-common \
		pkg-config \
		build-essential \
		unzip \
		wget \
		curl \
		git \
		# Required for wine
		flex \
		bison \
		libpng-dev \
	# Install vulkan
	&& wget -qO - http://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
	&& wget -qO /etc/apt/sources.list.d/lunarg-vulkan-1.1.92-bionic.list http://packages.lunarg.com/vulkan/1.1.92/lunarg-vulkan-1.1.92-bionic.list \
	&& apt update && apt install -y lunarg-vulkan-sdk \
	# Clean up
	&& apt autoremove -y \
		software-properties-common \
	&& apt autoclean \
	&& apt clean \
	&& apt autoremove

# https://www.wihlidal.com/blog/pipeline/2018-09-16-dxil-signing-post-compile/
WORKDIR /app
RUN wget -O signing.zip https://github.com/gwihlidal/dxil-signing/releases/download/0.1.2/dxil-signing-0_1_2.zip
RUN unzip -q signing.zip; exit 0
RUN mv dxil-signing-0_1_2 signing && rm -f signing.zip

# Download and install wine (for running FXC, DXIL signing tool, RGA for Windows)
ENV WINE_BRANCH=dxil
ENV WINE_REPO=https://github.com/gwihlidal/wine.git
ENV WINE_COMMIT=4777a57d8a5fd2c0aa0ba06abb9148f77b9c2ddf
WORKDIR /wine
RUN git clone --recurse-submodules -b ${WINE_BRANCH} ${WINE_REPO} /wine && \
	git checkout ${WINE_COMMIT} && \
	git reset --hard
RUN ./configure --enable-win64 --with-png --without-freetype && \
	make -j8 && \
	make install
ENV WINEARCH=win64
ENV WINEDEBUG=fixme-all
RUN winecfg

# Copy DXC binaries from dxc_builder stage into final stage (significant size reduction)
WORKDIR /app/dxc
COPY --from=dxc_builder /dxc/build/bin/dxc /app/dxc/bin/dxc
COPY --from=dxc_builder /dxc/build/lib/libdxcompiler.so.3.7 /app/dxc/lib/libdxcompiler.so.3.7
RUN ln -s /dxc/lib/libdxcompiler.so.3.7 /app/dxc/lib/libdxcompiler.so

# Copy FXC binaries into container
WORKDIR /app/fxc
COPY fxc_bin /app/fxc

# Download Linux and Windows binaries of AMD RGA
WORKDIR /app/rga
RUN wget -O rga_linux.tgz https://github.com/GPUOpen-Tools/RGA/releases/download/2.0.1/rga-linux-2.0.1.tgz && \
	tar zxf rga_linux.tgz && \
	mv rga-2.0.1.* linux && \
	rm rga_linux.tgz
RUN wget -O rga_windows.zip https://github.com/GPUOpen-Tools/RGA/releases/download/2.0.1/rga-windows-x64-2.0.1.zip
RUN unzip -q rga_windows.zip; exit 0
RUN mv bin windows && rm -f /app/rga/rga_windows.zip

# Convenient path variables
ENV DXC_PATH="/app/dxc/bin/dxc"
ENV FXC_PATH="/app/fxc/fxc.exe"
ENV SIGN_PATH="/app/signing/dxil-signing.exe"
ENV RGA_WIN_PATH="/app/rga/windows/rga.exe"
ENV RGA_NIX_PATH="/app/rga/linux/rga"

WORKDIR /app
ENTRYPOINT ["/bin/bash"]