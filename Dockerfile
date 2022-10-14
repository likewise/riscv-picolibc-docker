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
# (one per line)
RUN apt-get update && apt-get upgrade -y && apt-get update && apt-get install -y \
unzip help2man libtool-bin libncurses5-dev \
python3 meson \
libglib2.0 libpixman-1-dev

# build and install qemu to /opt
RUN git clone https://github.com/qemu/qemu.git && cd qemu && ./configure --target-list=riscv32-softmmu --prefix=/opt && make -j8 install && cd .. && rm -rf qemu

# build and install ct-ng to /opt
RUN (curl http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.25.0.tar.xz | tar xJ) && \
cd crosstool-ng-1.25.0 && ./configure --prefix=/opt && make -j8 install && cd .. && rm -rf crosstool-ng-1.25.0

# copy ct-ng configuration to build a cross toolchain for riscv, with picolibc companion library enabled
ADD riscv64-unknown-elf-picolibc.config /home/vexriscv/crosstool-riscv/.config
RUN chown -R vexriscv:vexriscv /home/vexriscv/crosstool-riscv && chmod -R go+r /home/vexriscv/crosstool-riscv

# switch to user to build the cross toolchain
USER vexriscv
WORKDIR /home/vexriscv

# meson from Ubuntu 18.04 is too old for picolibc, install a newer version, user local, using pip3
RUN pip3 install meson

# does not work
#RUN . ~/.profile
# add meson to path for the container build
ENV PATH="/home/vexriscv/.local/bin:${PATH}"
RUN meson --version
# add meson to path for the user
#RUN echo 'export PATH=/home/vexriscv/.local/bin:$PATH" >> ~/.bashrc
RUN meson --version

# fetch sources
RUN cd crosstool-riscv && /opt/bin/ct-ng source

# build and install cross toolchain
#RUN cd crosstool-riscv && /opt/bin/ct-ng build && cd .. && rm -rf crosstool-riscv
#RUN echo 'export PATH=$PATH:/home/vexriscv/x-tools/riscv64-unknown-elf/bin:' >> ~/.bashrc

USER vexriscv
WORKDIR /home/vexriscv

ENV COLORTERM="truecolor"
ENV TERM="xterm-256color"

