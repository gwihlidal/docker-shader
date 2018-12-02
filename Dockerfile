# https://www.wihlidal.com/blog/pipeline/2018-09-15-linux-dxc-docker/
FROM ubuntu:18.04 as dxc_builder
ENV DXC_BRANCH=master
ENV DXC_REPO=https://github.com/Microsoft/DirectXShaderCompiler.git
ENV DXC_COMMIT=545bf5e0c5527a7e904e4a559ad3c4f99cc610cb
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
		# Required for adding repositories
		software-properties-common \
		# Required for service compilation
		build-essential \
		libssl-dev \
		pkg-config \
		# Required for wine
		winbind \
		# Required for winetricks
		cabextract \
		p7zip \
		unzip \
		wget \
		curl \
		zenity \
	# Install vulkan
	&& wget -qO - http://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add - \
	&& wget -qO /etc/apt/sources.list.d/lunarg-vulkan-1.1.92-bionic.list http://packages.lunarg.com/vulkan/1.1.92/lunarg-vulkan-1.1.92-bionic.list \
	&& apt update && apt install -y lunarg-vulkan-sdk \
	# Install wine
	&& wget -O- https://dl.winehq.org/wine-builds/Release.key | apt-key add - \
	&& apt-add-repository https://dl.winehq.org/wine-builds/ubuntu/ \
	&& apt update \
	&& apt install -y --install-recommends winehq-stable \
	# Download wine cache files
	&& mkdir -p /home/wine/.cache/wine \
	&& wget https://dl.winehq.org/wine/wine-mono/4.7.3/wine-mono-4.7.3.msi \
		-O /home/wine/.cache/wine/wine-mono-4.6.4.msi \
	&& wget https://dl.winehq.org/wine/wine-gecko/2.47/wine_gecko-2.47-x86.msi \
		-O /home/wine/.cache/wine/wine_gecko-2.47-x86.msi \
	&& wget https://dl.winehq.org/wine/wine-gecko/2.47/wine_gecko-2.47-x86_64.msi \
		-O /home/wine/.cache/wine/wine_gecko-2.47-x86_64.msi \
	# Download winetricks and cache files
	&& wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
		-O /usr/bin/winetricks \
	&& chmod +rx /usr/bin/winetricks \
	&& mkdir -p /home/wine/.cache/winetricks/win7sp1 \
	&& wget https://download.microsoft.com/download/0/A/F/0AFB5316-3062-494A-AB78-7FB0D4461357/windows6.1-KB976932-X86.exe \
		-O /home/wine/.cache/winetricks/win7sp1/windows6.1-KB976932-X86.exe \
	# Create user and take ownership of files
	&& groupadd -g 1010 wine \
	&& useradd -s /bin/bash -u 1010 -g 1010 wine \
	&& chown -R wine:wine /home/wine \
	# Clean up
	&& apt autoremove -y \
		software-properties-common \
	&& apt autoclean \
	&& apt clean \
	&& apt autoremove
VOLUME /home/wine
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
RUN wget -O rga_windows.zip https://github.com/GPUOpen-Tools/RGA/releases/download/2.0.1/rga-windows-x86-2.0.1-cli-only.zip
RUN unzip -q rga_windows.zip; exit 0
RUN mv bin windows && rm -f /app/rga/rga_windows.zip

# https://www.wihlidal.com/blog/pipeline/2018-09-16-dxil-signing-post-compile/
WORKDIR /app
RUN wget -O signing.zip https://github.com/gwihlidal/dxil-signing/releases/download/0.1.2/dxil-signing-0_1_2.zip
RUN unzip -q signing.zip; exit 0
RUN mv dxil-signing-0_1_2 signing && rm -f signing.zip

# Convenient path variables
ENV DXC_PATH="/app/dxc/bin/dxc"
ENV FXC_PATH="/app/fxc/fxc.exe"
ENV SIGN_PATH="/app/signing/dxil-signing.exe"
ENV RGA_WIN_PATH="/app/rga/windows/rga.exe"
ENV RGA_NIX_PATH="/app/rga/linux/rga"

WORKDIR /app
ENTRYPOINT ["/bin/bash"]