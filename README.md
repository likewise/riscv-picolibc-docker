# riscv-picolibc-docker
Dockerfile to create a Docker image with development tools targetting bare-metal embedded software development targetting RISC-V running against picolibc. The
toolchain tests the picolibc hello-world against qemu-system-riscv32 during
building the docker image.

Remaining testing I am manually doing on 32-bit VexRiscv.

### Status
Hello world built against picolibc 1.7.9 runs on VexRiscv `-march=rv32i` `-mabi=ilp32`. Picolibc pico-hello example runs in QEMU rv32 virt target.

This should probably be changed to `-march=rv32i_zicsr`.

### Contents
 - QEMU
 - GCC cross toolchain including GDB
 - Crosstool-NG 1.25 based toolchain build (sample config included)
 
### Building the Docker image
`make build`

Depends on https://github.com/likewise/vexriscv-dockerfile.git Docker image.
(But easy to merge, no hard interdependencies.)

### Running the Docker image
`make run`

This mounts `/dev/usb` in the Docker container, allowing (sudo) OpenOCD to connect to a USB JTAG adapter on the host (tested with BusBlaster v2.5).

### Running the Docker image from a remote host
Assuming you are logged into a remote host that hosts this Docker image,
`make remote` to run the image inside a container, forwarding via X11.
