FROM archlinux:latest
# pacman -Syu
RUN pacman -Syyu --noconfirm; \
	pacman-db-upgrade;

# https://github.com/krevanth/ZAP#packages-required
RUN pacman -S --noconfirm \
	arm-none-eabi-gcc \
	arm-none-eabi-binutils \
	gdb \
	openocd \
	verilator \
	gtkwave \
	make \
	perl \	
	gcc   
