#!/bin/bash
#Author Pamenas 
#

part1_start="1"
part1_end="100"
part2_start=" "
part2_end="-1s"

partition_disk()
{
	if [[ -a $1 ]]; then
		echo "Using disk $1";
	else 
		printf "Error: Disk %s not found.\n" $1;
		return 1;
	fi
	if [[ parted -s $1 mklabel msdos ]] ; then
		echo "created msdos disk label for $1"
	else
		echo "failed to create disk label for $1"
	fi
	if [[ parted -s $1 mkpart p $part1_start $part1_end ]] ; then
		echo "created partition 1 on $1"
	else
		echo "failed to create partion 1 on $1"
	fi
	if[[ parted -s $1 -- mkpart p $part1_end $part2_end ]] ;then
		echo "created partition 2 on $1"
	else
		echo "failed to creat partion 2 on $1"
	fi
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
	if $(sudo kpartx -a $1); then

		echo "Kpartx succeeded setting up";
		
		echo "Formating partition one using "$l_1format;
		sudo mkfs.$l_1format /dev/mapper/$l_loop1;
		r_v1=$?
		echo "Formating partition two using "$l_2format;
		sudo mkfs.$l_2format /dev/mapper/$l_loop2;
		r_v2=$?		
		sudo kpartx -d $l_pnode
		
		rval=( $r_v1 -eq 0 -a $r_v2 -eq 0 )
		echo $rval
		return $rval

	else
		
		echo "Kpartx failed setting up. Exiting"
		return 1;
	fi
	return 1;
}

die() {
	echo "$*" >&2
	exit 1
}

title() {
	echo
	echo "==="
	echo "=== $* ==="
	echo "==="
}


#
# check if the loop file is already set up.
# return 0 if it is, and 1 if not
#
is_file_loop_setup()
{
	if $( losetup -j  $1 | grep $1 &> /dev/null  ) ; then
		return 0;
	else
		return 1;
	fi
}


#
# usage:
# loop_mount_disk <filedisk-image> <boot-mount-point> <root-mount-point>
loop_mount_disk()
{
	echo "loop_mount_disk called with $@"
	l_pnode=""
	l_p1=""
	l_p2=""
	l_1format="ext2"
	l_2format="ext3"
	l_pnode=$1
	l_loops=($( kpartx -l $l_pnode  | awk '{print $1 }' | grep 'loop[0-9]p[0-9]'))
	l_loop_count=${#l_loops[@]}
	l_loop1=""
	l_loop2=""
	
	
	is_file_loop_setup $1
	if (( $? == 0 )) ; then
		echo "Loop already mounted, try to unmount first (e.g. make removeloops)"
		exit 1   
	fi
	
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

#
# usage:
# extract <input-file> <target-directory>
extract()
{
	
	local f=$(readlink -f "$1")
	echo "Extracting $1 into $2"

	mkdir -p "$2"
	cd "$2"
	case "$f" in
	*.tar.bz2|*.tbz2)
		tar xjpf "$f"
		;;
	*.tar.gz|*.tgz)
		tar xzpf "$f"
		;;
	*.7z|*.lzma)
		7z x "$f"
		;;
	*.tar.xz)
		tar xJpf "$f"
		;;
	*)
		die "$f: unknown file extension"
		;;
	esac
	cd - > /dev/null
}



umount_delete_loop_device()
{

	declare -a loop_devices;
	declare -a unmounted_loops;
	declare -a difference;
	declare -a devices_of_interest

	mounted_loops=($( cat /proc/mounts | awk '/\/dev\/loop/  {print $1}'  ))
	loop_devices=$( losetup -a | grep "/dev/mapper/") 
	device_postfix=($( losetup -a | grep "/dev/loop"  | grep $1 | awk 'gsub(":","") {print $1} ' | awk 'gsub("/dev/","")' ))
	
	echo "Mounted Loops $mounted_loops"
	echo "Loop devices $loop_devices"
	echo "Device postfix $device_postfix"
	

	if [ "$device_postfix" = "" ];then
		echo "Nothing to unmount/delete";
		return 0;
	fi

	mapping=($( ls /dev/mapper | grep $device_postfix ))
	found=0

	for device in ${mapping[@]};do 
		if [ -z $device ] ; then 
			echo "empty";
			continue;
		fi
		to_search=($(losetup -a | grep "$device" | awk 'gsub(":","") {print $1} '))
		
		for x in ${mounted_loops[@]};do
			if [ "$x" = "$to_search" ]; then
				umount $x
			fi
		done
		
	done
	
	echo "Deleting loop devices for $1"
	sleep 1
	sudo kpartx -d $1 || 0
	sudo kpartx -d /dev/$device_postfix || 0
	sudo losetup -d /dev/$device_postfix || 0 	
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
	if [ -a $1 ] && [ -a $2 ]; then
		echo "Installing $1 to $2"
		sudo dd if=$1 of=$2 bs=1024 conv=notrunc seek=8
		if (( $? == 0 )) ; then
			echo "succeeded in installing uboot";
			return 0;
		else
			echo "failed to install uboot";
		fi;
	else
		echo "uboot_spl or filedisk-image not present"
	fi
	return 1;	
}
menu()
{
	opt_type="" #can be development or production
	output_file_size="" #size of rootfs
	output_directory="" #location of the files after work
	
	printf "Do you want a development or a production system?\nEnter p for production , d for development\n"
	read opt_type 
	printf "What size do you want for the rootfs , enter for default(2GB) in GBs?\n"
	read output_file_size
	printf "Choose your output directory, default in pwd?\n"
	read output_directory

#	echo $output_directory $opt_type $output_file_size
 	r_array=( $output_directory $opt_type $output_file_size )
	1=$r_array
	echo $(( $output_file_size * 100))
	return ${r_array[@]}
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

check_if_filedisk_mounted()
{
	declare -a loop_devices;
	declare -a unmounted_loops;
	declare -a difference;
	declare -a devices_of_interest

	mounted_loops=($( cat /proc/mounts | awk '/\/dev\/loop/  {print $1}'  ))
	loop_devices=$( losetup -a | grep "/dev/mapper/") 
	device_postfix=($( losetup -a | grep "/dev/loop"  | grep $1 | awk 'gsub(":","") {print $1} ' | awk 'gsub("/dev/","")' ))
	

	if [ "$device_postfix" = "" ];then
		echo "";
		return 0;
	fi

	mapping=($( ls /dev/mapper | grep $device_postfix ))
	

	for device in ${mapping[@]};do 
		if [ -z $device ] ; then 
			echo "empty";
			continue;
		fi
		to_search=($(losetup -a | grep "$device" | awk 'gsub(":","") {print $1} '))
		
		found=0
		
		for x in ${mounted_loops[@]};do
			if [ "$x" = "$to_search" ]; then
				found=1;
				break;
			fi
		done
		
		if [[ $found == 0 ]]; then
			unmounted_loops[${#unmounted_loops[@]}]="/dev/mapper/"$device;
		fi	
	done
	
	
	echo ${unmounted_loops[@]}	
}



test_for_requirements()
{
	echo $1 $2 $3
	declare -a missing_files;
#test for kpartx
	kpartx_file=($( whereis kpartx | awk '{ print $2 }' | grep kpartx ) )
#test for losetup
	losetup_file=($( whereis losetup | awk '{ print $2 }' | grep losetup ) )
#test for sfdisk
	sfdisk_file=($( whereis sfdisk | awk '{ print $2 }' | grep sfdisk ) )
#test for mkfs
	mkfs_file=($( whereis mkfs | awk '{ print $2 }' | grep mkfs ) )
	
	if ! [[ -x $kpartx_file ]] ; then
		missing_files[${#missing_files[@]}]="kpartx";
		
	fi
	if  ! [[ -x $losetup_file ]] ; then
		missing_files[${#missing_files[@]}]="losetup";
	fi
	if ! [[ -x $sfdisk_file ]] ; then
		missing_files[${#missing_files[@]}]="sfdisk";
	fi
	if ! [[ -x $mkfs_file ]] ; then
		missing_files[${#missing_files[@]}]="mkfs";
	fi
	if [[ ${#missing_files[@]} > 0 ]]; then
		echo "Please install the following programs inorder to continue ";
		echo ":${missing_files[@]}";
		return 1;
	else
		return 0;
	fi
	
}

#start of copy
copy_data ()
{
	local d= x=
	local rootfs_copied=
	local HWPACKDIR=$1
	local MNTROOT=$2
	local MNTBOOT=$3
	local ROOTFSDIR=$4
	
	echo "Copy VFAT partition files to SD Card"
	cp $HWPACKDIR/kernel/uImage $MNTBOOT ||
		die "Failed to copy VFAT partition data to SD Card"
	cp $HWPACKDIR/kernel/*.bin $MNTBOOT/script.bin ||
		die "Failed to copy VFAT partition data to SD Card"
	if [ -s $HWPACKDIR/kernel/*.scr ]; then
		cp $HWPACKDIR/kernel/*.scr $MNTBOOT/boot.scr ||
			die "Failed to copy VFAT partition data to SD Card"
	fi

    if [[ ${hwpack_update_only} -eq 0 ]]; then
		title "Copy rootfs partition files to SD Card"
		for x in '' \
			'binary/boot/filesystem.dir' 'binary'; do

			d="$ROOTFSDIR${x:+/$x}"

			if [ -d "$d/sbin" ]; then
				rootfs_copied=1
				cp -a "$d"/* "$MNTROOT" ||
					die "Failed to copy rootfs partition data to SD Card"
				break
			fi
		done

		[ -n "$rootfs_copied" ] || die "Unsupported rootfs"
        fi

	title "Copy hwpack rootfs files"
	# Fedora uses a softlink for lib.  Adjust, if needed.
	if [ -L $MNTROOT/lib ]; then
		# Find where it points.  For Fedora, we expect usr/lib.
		DEST=`/bin/ls -l $MNTROOT/lib | sed -e 's,.* ,,'`
		if [ "$DEST" = "usr/lib" ]; then
			d="$HWPACKDIR/rootfs"
			if [ -d "$d/lib" ]; then
				mkdir -p "$d/usr/lib/"
				mv "$d/lib"/* "$d/usr/lib/"
				rmdir "$d/lib"
			fi
		fi
	fi
        cp -a $HWPACKDIR/rootfs/* $MNTROOT/ ||
		die "Failed to copy rootfs hwpack files to SD Card"
}
#####end of copy
# execute first parameter as function, pass the remaining
# arguments to the function
FUNC=$1
shift
$FUNC $@



#partition_disk $1
#export -f format_disk
#export -f loop_mount_disk
#export -f umount_delete_loop_device
#export -f test_for_requirements
#su -c 'format_disk '$1
#su -c 'loop_mount_disk '$1' '$2' '$3
#su -c 'umount_delete_loop_device $1'



