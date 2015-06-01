setenv bootdelay 0
setenv bootargs console=ttyS0,115200 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait panic=10 ${extra}
saveenv
