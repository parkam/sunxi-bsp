sunxi-bsp
=========

Getting Started
---------------
This branch/fork is optimized for Cubieboard2 boards. It
might work with other boards, but will most likely fail.

Checkout the repo and *this* branch, then configure and build the filedisk. Finally put it on your
sd-card
As with the original BSP, you'll need a root file system, e.g. a linaro or ubuntu.

1. git clone *<repo-url>*
2. git checkout filedisk
3. ./configure cubieboard2
4. make filedisk ROOTFS=*<path-to-rootfs>*
5. make optimize
6. dd if=output/filedisk.img of=/dev/sdx bs=1M

The tasks are organized in the Makefile that will execute the appropriate functions in scripts/.
