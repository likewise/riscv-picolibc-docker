# This is based on vexriscv image (targeting SpinalHDL / VexRiscv development)
# However, I think there are no cross-dependencies; if you need a single image
# description you might want to copy-paste the base setup of that image.
FROM vexriscv:latest

USER root
WORKDIR /

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

# add crosstool configuration for riscv+picolibc
# wow, the ADD/COPY command syntax is really horrible if you want to copy directories recursively...#
ADD riscv32-unknown-elf-picolibc /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc
RUN sed -ri 's@^CT_PICOLIBC_DEVEL_BRANCH=.*@CT_PICOLIBC_DEVEL_BRANCH="1.7.9"@' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config && \
grep -e 'CT_PICOLIBC_DEVEL_BRANCH="1.7.9"' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config
RUN sed -ri 's@^(# CT_TEST_SUITE_GCC is not set|CT_TEST_SUITE_GCC=.*)@CT_TEST_SUITE_GCC=y@' /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config

#ADD riscv64-unknown-elf-picolibc /opt/share/crosstool-ng/samples/riscv64-unknown-elf-picolibc

# verify that worked
RUN head /opt/share/crosstool-ng/samples/riscv32-unknown-elf-picolibc/crosstool.config
#RUN chown -R vexriscv:vexriscv /home/vexriscv/crosstool-riscv && chmod -R go+r /home/vexriscv/crosstool-riscv

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
RUN echo 'export PATH=$PATH:/home/vexriscv/x179/riscv32-unknown-elf/bin' >> ~/.bashrc

# make cross toolchain and qemu available during container build
ENV PATH="${PATH}:/home/vexriscv/x179/riscv32-unknown-elf/bin:/opt/bin"

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

USER vexriscv
WORKDIR /home/vexriscv

ENV COLORTERM="truecolor"
ENV TERM="xterm-256color"

