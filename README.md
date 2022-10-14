# riscv-dockerfile
Dockerfile to create Docker image for embedded software development for RISC-V using picolibc

### Status
Work in progress on toolchain setup, especially the picolibc part

### Contents
QEMU
GCC cross toolchain including GDB

### Building the Docker image
make build

### Running the Docker image
make run

This mounts the /dev/usb in the Docker container, allowing (sudo) OpenOCD to connect to a USB JTAG adapter on the host (tested with BusBlaster v2.5).
