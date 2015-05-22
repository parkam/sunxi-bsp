#!/bin/bash


part1_start="0"
part1_end="50"
part2_start=" "
part2_end=" "

SPRINTF_ARGS="%s,%s;\n%s,%s;\n;\n;\nEOF "$part1_start" "$part1_end" "$part2_start" "$part2_end

partition_disk()
{
	if [[ -a $1 ]]; then
		echo "Using disk $1";
	else 
		printf "Error: Disk %s not found.\n" $1;
		return 1;
	fi
	printf $SPRINTF_ARGS | sfdisk  $1 -uM 
}
#This function formats a disk by using device mapping setup by kpartx
#and then formats the loops that kpartx setup at /dev/mapper/loop*
#subsequently unmounts the disk
#takes the following arguments in the order
#diskname, partition_1 format, partition_2 format
format_disk()
{
	l_pnode=""
	l_p1=""
	l_p2=""
	l_1format="ext2"
	l_2format="ext3"
	l_pnode=$1
	echo "confirming arg1 $l_pnode $1"
	l_loops=($( kpartx -l $1  | awk '{print $1 }' | grep 'loop[0-9]p[0-9]'))
	echo $?
	l_loop_count=${#l_loops[@]}
	l_loop1=""
	l_loop2=""
	echo $l_loops
	if (($l_loop_count > 1)); then
		l_loop1=${l_loops[0]};
		l_loop2=${l_loops[1]};
	else 
		l_loop1=${l_loops[0]};
	fi	
 		echo $l_loop1  $l_loop2 
		echo "before kpartx" $1
	if $(kpartx -a $1); then

		echo "Kpartx succeeded setting up";
		
		echo "Formating partition one using "$l_1format;
		mkfs.$l_1format /dev/mapper/$l_loop1;
		r_v1=$?
		echo "Formating partition two using "$l_2format;
		mkfs.$l_2format /dev/mapper/$l_loop2;
		r_v2=$?		
		kpartx -d $l_pnode
		
		rval=( $r_v1 -eq 0 -a $r_v2 -eq 0 )
		echo $rval
		return $rval

	else
		
		echo "Kpartx failed setting up. Exiting"
		return 1;
	fi
	return 1;
}

loop_mount_disk()
{
	l_pnode=""
	l_p1=""
	l_p2=""
	l_1format="ext2"
	l_2format="ext3"
	l_pnode=$1
	l_loops=($( kpartx -l $l_pnode  | awk '{print $1 }' | grep 'loop[0-9]p[0-9]'))
	echo $?
	l_loop_count=${#l_loops[@]}
	l_loop1=""
	l_loop2=""
	
	if (($l_loop_count > 1)); then
		l_loop1=${l_loops[0]};
		l_loop2=${l_loops[1]};
	else 
		l_loop1=${l_loops[0]};
	fi	
	echo $@
	if ! [ -d "$2" ]; then
		echo "requested mount point $2 does not exist"
		return -1;
	fi
	if ! [ -d "$3" ]; then
		echo "requested mount point $3 does not exist"
		return -1;
	fi
	$( kpartx -a -s $1 )
	sleep 2
	mount -o loop /dev/mapper/$l_loop1 $2

	rv1=$?
	mount -o loop /dev/mapper/$l_loop2 $3
	rv2=$?
	
}



delete_plymouth_files()
{
	r_dir=$1
	if [-d $r_dir ];then
		rm -rf $r_dir/etc/init/plymouth*
		return $?;
	fi
	return 1;
}
#This function extracts archived boot files to boot directory
#argument 1 is boot directory to install , argument two is the archive files
#
copy_boot_files()
{
	b_dir=$1
	if [[ -d $b_dir ]]; then
		if ((tar -xvf $2 -C $b_dir)) ; then 
			echo "Succeeded in copying boot files";
			return 0;
		fi;
	fi
		echo "Failed to copy boot files to $1"
	return 1;
}
#This function takes the rfs image file as argument 1 and u-boot-with-spl-as argument 2 and
#installs the u-boot file to rfs image file.
install_uboot_spl()
{
	if [ -a $1 && -a $2 ]; then
		echo "Installing $2 to $1";
		if ((dd if=$2 of=$2 bs=1024 conv=notrunc seek=8)); then
			echo "succeeded in installing uboot";
			return 0;
		else
			echo "failed to install uboot";
		fi;
	fi
	return 1;	
}

clone_patch_compile_uboot()
{
	l_workingdir=$1
	ubooturl=$2
	l_board=$3
	pushd $l_workingdir/uboot
	git clone $ubooturl
	cp $l_workingdir/uboot/prod_patch $l_workingdir/uboot/u-boot-sunxi
	pushd $l_workingdir/uboot/u-boot-sunxi
	patch prod_patch
	
	make $l_board"_config" ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
	make -j4 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
	cp ./u-boot-sunxi-with-spl.bin $l_workingdir/uboot/binary
	popd
	popd
	return 0 
}

partition_disk $1
export -f format_disk
export  -f loop_mount_disk
su -c 'format_disk '$1
su -c 'loop_mount_disk '$1' '$2' '$3

