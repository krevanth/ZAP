FROM archlinux:latest
RUN  pacman -Syyu --noconfirm arm-none-eabi-gcc arm-none-eabi-binutils gcc make perl verilator
