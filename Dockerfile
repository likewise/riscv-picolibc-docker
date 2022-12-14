# This is based on vexriscv image (targeting SpinalHDL / VexRiscv development)
# However, I think there are no cross-dependencies; if you need a single image
# description you might want to copy-paste the base setup of that image.
FROM vexriscv:latest

USER root
WORKDIR /

USER root
WORKDIR /

# Generate and configure the character set encoding to en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en

# @TODO fix this warning: /bin/bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
RUN locale-gen --purge en_US.UTF-8
RUN echo -e 'LANG="en_US.UTF-8"\nLANGUAGE="en_US:en"\n' > /etc/default/locale

# https://github.com/five-embeddev/riscv-scratchpad/blob/master/cmake/cmake/riscv.cmake
# https://keithp.com/picolibc/
# https://crosstool-ng.github.io/docs/build/

# Install dependencies for:
# crosstool-ng
# picolibc
# qemu
# (dependencies per line)
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
unzip help2man libtool-bin libncurses5-dev \
python3 meson \
libglib2.0 libpixman-1-dev device-tree-compiler
# device-tree-compiler is not a dependency but can be used
# to modify virtual machines in qemu using a modified dtb

# build and install qemu to /opt
RUN git clone https://github.com/qemu/qemu.git && cd qemu && ./configure --target-list=riscv32-softmmu --prefix=/opt && make -j8 install && cd .. && rm -rf qemu

# build and install ct-ng to /opt
RUN (curl http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.25.0.tar.xz | tar xJ) && \
cd crosstool-ng-1.25.0 && ./configure --prefix=/opt && make -j8 install && cd .. && rm -rf crosstool-ng-1.25.0

# copy ct-ng configuration to build a cross toolchain for riscv, with picolibc companion library enabled
RUN ls -al /opt/share/crosstool-ng/samples/ | grep riscv

# add crosstool configuration for riscv with newlib and picolibc, this contains the install path also
# wow, the ADD/COPY command syntax is really horrible if you want to copy directories recursively...#
ADD riscv32-unknown-elf-picolibc /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc

# switch to picolib 1.7.9
RUN sed -ri 's@^CT_PICOLIBC_DEVEL_BRANCH=.*@CT_PICOLIBC_DEVEL_BRANCH="1.7.9"@' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config && \
grep -e 'CT_PICOLIBC_DEVEL_BRANCH="1.7.9"' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config
# enable GCC test suite
RUN sed -ri 's@^(# CT_TEST_SUITE_GCC is not set|CT_TEST_SUITE_GCC=.*)@CT_TEST_SUITE_GCC=y@' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config

#ADD riscv64-unknown-elf-picolibc /opt/share/crosstool-ng/samples/riscv64-unknown-elf-picolibc

# verify that the configuration is in place
RUN head /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config

# switch to user to build the cross toolchain
USER vexriscv
WORKDIR /home/vexriscv

# configure crosstool-ng to build a riscv32 picolibc toolchain and fetch sources
RUN mkdir crosstool-riscv32 && cd crosstool-riscv32 && /opt/bin/ct-ng riscv32-unknown-elf-picolibc && /opt/bin/ct-ng source
# build

# meson from Ubuntu 18.04 is too old for picolibc, install a newer version, user local, using pip3
RUN pip3 install meson

# make meson, ct-ng and qemu accessible via PATH to user
RUN echo 'export PATH=/home/vexriscv/.local/bin:$PATH:/opt/bin' >> /home/vexriscv/.bashrc

# make meson available during container build
ENV PATH="/home/vexriscv/.local/bin:${PATH}"
RUN echo PATH=$PATH && meson --version && cd crosstool-riscv32 && /opt/bin/ct-ng build

#RUN echo 'export PATH=$PATH:/home/vexriscv/x-tools/riscv32-unknown-elf/bin' >> ~/.bashrc
RUN echo 'export PATH=$PATH:/home/vexriscv/x-tools/riscv32-unknown-elf/bin' >> ~/.bashrc

# make cross toolchain and qemu available during container build
ENV PATH="${PATH}:/home/vexriscv/x-tools/riscv32-unknown-elf/bin:/opt/bin"

# build the hello world example, run it semihosted in qemu and verify it runs correctly
RUN git clone --branch=1.7.9 --depth=1 https://github.com/picolibc/picolibc.git && \
cd picolibc/hello-world && sed -i 's@riscv64@riscv32@' Makefile && make hello-world-riscv.elf && ./run-riscv 2>&1 | grep -e 'hello, world'

# does not work
#RUN . ~/.profile
# add meson to path for the container build
#ENV PATH="/home/vexriscv/.local/bin:${PATH}"
# add meson to path for the user

# build and install cross toolchain
#RUN cd crosstool-riscv && /opt/bin/ct-ng build && cd .. && rm -rf crosstool-riscv
#RUN echo 'export PATH=$PATH:/home/vexriscv/x-tools/riscv64-unknown-elf/bin:' >> ~/.bashrc

USER root
WORKDIR /

# to create TAP0 for testing purposes (CocoTB)
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
iproute2 uml-utilities iputils-ping netcat

# to create Wireguard packets from within container
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
wireguard-tools

# we used this once, then we stored the private key here -- this is the private key of the container guest
#RUN cd /etc/wireguard/ && wg genkey > /etc/wireguard/private.key && chmod go= /etc/wireguard/private.key && \
RUN cd /etc/wireguard/ && echo "MIuE1NHyNFf++dzYbFkn3pn9ouRVUtSHShYL791NcEg=" > /etc/wireguard/private.key && chmod go= /etc/wireguard/private.key && \
cat /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key && echo -n "[Interface]\nPrivateKey = " > /etc/wireguard/wg0.conf && \
chmod go= /etc/wireguard/wg0.conf && \
cat private.key >> /etc/wireguard/wg0.conf && echo -n "Address = 10.8.0.1/24\n\n" >> /etc/wireguard/wg0.conf && \
echo -n "[Peer]\nPublicKey = X6NJW+IznvItD3B5TseUasRPjPzF0PkM5+GaLIjdBG4=\nAllowedIPs = 10.8.0.0/24\nEndpoint = 192.168.255.2:51820\n" >> /etc/wireguard/wg0.conf
# matches the hard-coded private key inside wg_lwip.

# xeyes, to verify SSH/X11 forwarding and have visual feedback on mouse input, return screen latency
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
x11-apps

# https://github.com/themperek/cocotb-test/commit/30176257d4052da639fe6a715cee705af385a210
# Fixes: No module named 'cocotb._vendor.find_libpython'
# Issued here: https://github.com/cocotb/cocotb/issues/3131
RUN sed -i \
-e 's@import cocotb._vendor.find_libpython as find_libpython@import find_libpython@' \
-e 's@install_requires=["cocotb>=1.5", "pytest"],@install_requires=["cocotb>=1.5", "pytest", "find_libpython"],@' \
`find /usr/local/lib/python*/*-packages/cocotb_test/simulator.py`
#git clone https://github.com/themperek/cocotb-test.git && cd cocotb-test.git && git format-patch -1 30176257d4052da639fe6a715cee705af385a210

RUN (curl http://ghdl.free.fr/site/uploads/Main/ghdl-i686-linux-latest.tar | tar xv) && \
cd ghdl-0.29-i686-pc-linux/ && tar -C / -jxvf ghdl-0.29-i686-pc-linux.tar.bz2

USER vexriscv
WORKDIR /home/vexriscv

# This is how to install cocotb-test 0.2.3 for user, it has above fix, but requires Python 3.7 
#pip3 install -v https://github.com/themperek/cocotb-test/archive/refs/tags/v0.2.3.zip

#RUN pip3 install cocotb-test
#RUN sed -i \
#-e 's@import cocotb._vendor.find_libpython as find_libpython@import find_libpython@' \
#-e 's@install_requires=["cocotb>=1.5", "pytest"],@install_requires=["cocotb>=1.5", "pytest", "find_libpython"],@' \
#`find /home/vexriscv/.local/lib/python*/*-packages/cocotb_test/simulator.py` || true

ENV COLORTERM="truecolor"
ENV TERM="xterm-256color"
