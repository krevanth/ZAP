If your site does not provide Verilator >= 4.x, you should use docker. Assuming you are part of docker group, simply do:

```bash
make -f docker.mk
```

If your distro does provide Verilator >= 4.x, you simply need to install the required packages at your site: verilator, 
gcc, arm-none-eabi-gcc, perl, gtkwave, gdb, openocd, make. Once installed, simply do:

```bash
make -f make.mk
```

