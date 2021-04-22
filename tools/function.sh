function usage {

	echo "Usage: 
 mkminios <option> [<project codename>] - Image Generator for Mini OS

Options:
	all		Execute the whole process of creating a project image
	clean		Removes most generated files
	image		Genreate image from the working directory
	sqf_image	Genreate squashfs image from the working directory
	test		Invoke 'QEMU' to test image with bundled kernel
	mkopt		Create opt package using recipe or directory
	help		Display this help

For further informations please refer to README file."
}

function clean {
	rm -rf working/${MKMINIOS_CODENAME} deploy/${MKMINIOS_CODENAME} deploy/${MKMINIOS_CODENAME}.cpio deploy/${MKMINIOS_CODENAME}.iso
}

function setup {

	echo "[mkminios] Setup Project: $1"
	MKMINIOS_CODENAME=$1
	mkdir -p working/${MKMINIOS_CODENAME}
	mkdir -p deploy/${MKMINIOS_CODENAME}
	export MKMINIOS_CONFIG=config/${MKMINIOS_CODENAME}.cookbook
	eval export `./tools/parser ${MKMINIOS_CONFIG} config`

	# copy initramfs skeleton
	tools/mkinitramfs -m working/${MKMINIOS_CODENAME}
#	cp -rfp --remove-destination skeleton/initramfs/ working/${MKMINIOS_CODENAME}/initramfs

	# untar rootfs skeleton
	tar zxf skeleton/rootfs.tgz -C working/${MKMINIOS_CODENAME}/
	export MKMINIOS_TARGET=working/${MKMINIOS_CODENAME}/rootfs

	echo "[mkminios] Project Target: ${MKMINIOS_TARGET}"
	
	echo "[mkminios] Executing pre-build scripts:"
	eval `./tools/parser ${MKMINIOS_CONFIG} prepare`

}

function install {

	echo "    Preparing recipes..."
	for R in `./tools/parser ${MKMINIOS_CONFIG} recipe`; do 
		for P in `./tools/parser package/recipe/$R.recipe package`; do
		PACKAGE="$PACKAGE $P"
		done
	done
	# add OPT packages
	for R in `./tools/parser ${MKMINIOS_CONFIG} opt`; do 
		for P in `./tools/parser package/recipe/$R.recipe package`; do
		PACKAGE="$PACKAGE $P"
		done
	done

	if [ "$MKMINIOS_PKGMGR" != 'skip' ]; then
		$MKMINIOS_PKGMGR $PACKAGE
	else 
		echo "You need to install following packages according to your cookbook: "
		echo "$PACKAGE"
	fi

}
# copy files from recipe section to working fs
# copyfiles (section_name) (destination) (file)
function copyfiles {
	case $1 in
		binary)
			## host binaries
			[ -d $2/`dirname $3` ] || mkdir -p $2/`dirname $3`
			cp -rfp --remove-destination $3 $2/$3
		;;
		data)
			## host data files
			[ -d $2/`dirname $3` ] || mkdir -p $2/`dirname $3`
			cp -rfp --remove-destination $3 $2/$3
		;;
		config)
			## package/config/*
			[ -d $2/`dirname $3` ] || mkdir -p $2/`dirname $3`
			cp -rfp --remove-destination package/config/$3 $2/$3
		;;
		alternative)
			## package/alternative/${MKMINIOS_CODENAME}
			if [ -e package/alternative/${MKMINIOS_CODENAME} ]; then
				[ -d $2/`dirname $3` ] || mkdir -p $2/`dirname $3`
				cp -rfpL --remove-destination package/alternative/${MKMINIOS_CODENAME}/$3 $2/$3
			fi
		;;
		overwrite)
			## skeleton/overwrite/
			[ -d $2/`dirname $3` ] || mkdir -p $2/`dirname $3`
			cp -rfp skeleton/overwrite/$3 $2/$3
		;;
	esac
}

function strip {

	echo "    Copying files to rootfs..."
	for R in `./tools/parser ${MKMINIOS_CONFIG} recipe`; do 
		
		# action 
		eval `./tools/parser package/recipe/$R.recipe action`

		for S in binary data config alternative overwrite; do
		
			for A in `./tools/parser package/recipe/$R.recipe $S`; do
				copyfiles $S ${MKMINIOS_TARGET} $A
			done 
		done 

		# post action 
		eval `./tools/parser package/recipe/$R.recipe post_action`
		
	done

}

function init {

	echo "    Creating initramfs..."
	
	R="initramfs"
	COPY_DESTINATION="working/${MKMINIOS_CODENAME}/initramfs"
	# action 
	eval `./tools/parser package/recipe/$R.recipe action`

	for S in binary data config alternative overwrite; do
		
		for A in `./tools/parser package/recipe/$R.recipe $S`; do
				copyfiles $S $COPY_DESTINATION $A
			done
			
	done 

	# post action 
	eval `./tools/parser package/recipe/$R.recipe post_action`
}

function opt {

	echo "    Creating Opt files..."
	for R in `./tools/parser ${MKMINIOS_CONFIG} opt`; do 
		
		# action 
		eval `./tools/parser package/recipe/$R.recipe action`
		
		# create opt directory
		NAME=`./tools/parser package/recipe/$R.recipe name`
		mkdir -p ${MKMINIOS_TARGET}/opt/$NAME

		for S in binary data config overwrite; do
		
			for A in `./tools/parser package/recipe/$R.recipe $S`; do
				copyfiles $S ${MKMINIOS_TARGET}/opt/$NAME $A
			done 
		done 

		# post action 
		eval `./tools/parser package/recipe/$R.recipe post_action`
		
	done

}

function kernel {

	echo "[mkminios] Adding kernel modules"
	
	MKMINIOS_CODENAME=$1
	export MKMINIOS_CONFIG=config/${MKMINIOS_CODENAME}.cookbook
	eval export `./tools/parser ${MKMINIOS_CONFIG} config`
	export MKMINIOS_TARGET=working/${MKMINIOS_CODENAME}/rootfs
	
	for MOD in `./tools/parser ${MKMINIOS_CONFIG} module`; do
		for M in `./tools/module-helper $MOD`; do
		
		## FIXME: workaround with different kernel path
		if [ `echo $M | grep "^/"` ]; then
			[ -d ${MKMINIOS_TARGET}/`dirname $M` ] || mkdir -p ${MKMINIOS_TARGET}/`dirname $M` 
			cp -rfpL --remove-destination $M ${MKMINIOS_TARGET}/$M
		else 
			[ -d ${MKMINIOS_TARGET}/$MKMINIOS_MOD_PATH/`dirname $M` ] || mkdir -p ${MKMINIOS_TARGET}/$MKMINIOS_MOD_PATH/`dirname $M` 
			cp -rfpL --remove-destination $MKMINIOS_MOD_PATH/$M ${MKMINIOS_TARGET}/$MKMINIOS_MOD_PATH/$M
		fi
		done
	done

	depmod -b ${MKMINIOS_TARGET} ${MKMINIOS_KERNEL}

}

# helper for copying file dependencies
# copydeps (file) (target directory)
function copydeps {
		for i in `./tools/ldd-helper "$1"`; do 
			TARGET=`dirname $i`
			if [ ! -e ${MKMINIOS_TARGET}$i ]; then
				if [ ! -e $2$TARGET ]; then
					mkdir -p $2$TARGET
				fi
				cp -rfpL --remove-destination $i $2$TARGET
				# uncomment following line for thorough dependency check
				#copydeps $i $2
			fi
		done
}

# post 
function post {

	echo "[mkminios] Post-install scripts"

	# create symbolic links for /bin/*
	./tools/busybox-helper
#	rm ${MKMINIOS_TARGET}/bin/busybox

	# check initramfs dependencies
	# FIXME: set initramfs directory as variable
	echo "    Checking initramfs dependencies"
	INITRAMFS_DIR="working/${MKMINIOS_CODENAME}/initramfs"
	for s in `find $INITRAMFS_DIR -type f`; do
		copydeps $s $INITRAMFS_DIR
	done

	# check file dependencies
	echo "    Checking rootfs dependencies"
	for s in `find ${MKMINIOS_TARGET}/{usr,lib,bin,sbin}/ -type f`; do
		copydeps $s ${MKMINIOS_TARGET}
	done

	# check dependencies of opt
	for O in `./tools/parser ${MKMINIOS_CONFIG} opt`; do 
		NAME=`./tools/parser package/recipe/$O.recipe name`
		echo "    Checking dependencies of $NAME opt"
		find ${MKMINIOS_TARGET}/opt/$NAME/ -type f | while read s
		do
			copydeps "$s" ${MKMINIOS_TARGET}/opt/$NAME
		done
	done

	eval `./tools/parser ${MKMINIOS_CONFIG} action`
	
	# pack binaries with upx 
	if [ -e /usr/bin/upx ]; then 
		for o in `./tools/parser ${MKMINIOS_CONFIG} obfuscate`; do
			if [ -e ${MKMINIOS_TARGET}/$o ]; then
			upx ${MKMINIOS_TARGET}/$o
			fi
		done
	fi

}

function sqf_image {

	echo "[mkminios] Generating squashfs image..."
	MKMINIOS_CODENAME=$1
	export MKMINIOS_CONFIG=config/${MKMINIOS_CODENAME}.cookbook
	eval export `./tools/parser ${MKMINIOS_CONFIG} config`
	export MKMINIOS_TARGET=working/${MKMINIOS_CODENAME}/rootfs

	# temporary hook for squashfs version 
	if [ -e /usr/bin/mksquashfs ]; then 
		MKSQF="mksquashfs" 
	else 
		echo "Error - not found mksquashfs."
		exit;
	fi
		
	# enable multi-layered rootfs support for Opts 
	for R in `./tools/parser ${MKMINIOS_CONFIG} opt`; do 
		NAME=`./tools/parser package/recipe/$R.recipe name`
		
		if [ ! -e ${MKMINIOS_TARGET}/opt/$NAME ];then

			mv working/${MKMINIOS_CODENAME}/$NAME ${MKMINIOS_TARGET}/opt/
			
		fi

			# create .opt file
			cd  ${MKMINIOS_TARGET}/opt/
			$MKSQF $NAME $NAME.opt -noappend 
			cd -
			
			# move opt directory out from rootfs
			mv ${MKMINIOS_TARGET}/opt/$NAME working/${MKMINIOS_CODENAME}/
		
		cd ${MKMINIOS_TARGET}
			# create the cpio.gz format file to be loaded at boot
#			find opt/$NAME.opt | cpio -H newc -o | gzip -9 > ../../../deploy/${MKMINIOS_CODENAME}/$NAME
			# clean up .opt file 
			mv opt/$NAME.opt ../../../deploy/${MKMINIOS_CODENAME}/
			rm -f opt/$NAME.opt
		cd -
		
	done
	
	# create compressed rootfs to /opt/rootfs.sqf
#	cp skeleton/overwrite/bin/busybox ${MKMINIOS_TARGET}/bin/busybox 
#	$MKSQF ${MKMINIOS_TARGET}/ working/${MKMINIOS_CODENAME}/initramfs/opt/rootfs.sqf -noappend 
        $MKSQF ${MKMINIOS_TARGET}/ deploy/${MKMINIOS_CODENAME}/system.img -noappend

#	cp working/${MKMINIOS_CODENAME}/initramfs/opt/rootfs.sqf deploy/${MKMINIOS_CODENAME}/${MKMINIOS_CODENAME}.img
#	du -h deploy/${MKMINIOS_CODENAME}/${MKMINIOS_CODENAME}.img
	du -h deploy/${MKMINIOS_CODENAME}/system.img

	## FIXME: use variable instead of actual initramfs path
	cd working/${MKMINIOS_CODENAME}/initramfs
	find | cpio -H newc -o > ../../../deploy/${MKMINIOS_CODENAME}.cpio
	cd -

	for format in `./tools/parser ${MKMINIOS_CONFIG} image`; do 
	
	case $format in
			gz)
				cat deploy/${MKMINIOS_CODENAME}.cpio | gzip -9 > deploy/${MKMINIOS_CODENAME}/initrd.img
				du -h deploy/${MKMINIOS_CODENAME}/initrd.img
			;;
			iso)
				cp -r skeleton/boot/iso/ deploy/${MKMINIOS_CODENAME}/
				cp ${MKMINIOS_KERNEL_IMAGE} deploy/${MKMINIOS_CODENAME}/iso/boot/kernel
				cp deploy/${MKMINIOS_CODENAME}/initrd.img deploy/${MKMINIOS_CODENAME}/iso/boot/initrd.img
				cp deploy/${MKMINIOS_CODENAME}/system.img deploy/${MKMINIOS_CODENAME}/iso/boot/system.img
				cp deploy/${MKMINIOS_CODENAME}/*.opt deploy/${MKMINIOS_CODENAME}/iso/boot/opt/
				mkisofs -R -l -V 'StarOS' -input-charset utf-8 -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o deploy/${MKMINIOS_CODENAME}.iso deploy/${MKMINIOS_CODENAME}/iso/
				rm -rf deploy/${MKMINIOS_CODENAME}/iso/
				./tools/isohybrid deploy/${MKMINIOS_CODENAME}.iso
				du -h deploy/${MKMINIOS_CODENAME}.iso
			;;
			*)
			echo "$format: not supported format"
			;;
	esac 
	done

}

function image {

	echo "[mkminios] Generating image..."
	MKMINIOS_CODENAME=$1
	export MKMINIOS_CONFIG=config/${MKMINIOS_CODENAME}.cookbook
	eval export `./tools/parser ${MKMINIOS_CONFIG} config`
	export MKMINIOS_TARGET=working/${MKMINIOS_CODENAME}/rootfs

	# temporary hook for squashfs version 
	if [ -e /usr/bin/mksquashfs ]; then 
		MKSQF="mksquashfs" 
	else 
		echo "Error - not found mksquashfs."
		exit;
	fi
		
	# enable multi-layered rootfs support for Opts 
	for R in `./tools/parser ${MKMINIOS_CONFIG} opt`; do 
		NAME=`./tools/parser package/recipe/$R.recipe name`
		
		if [ ! -e ${MKMINIOS_TARGET}/opt/$NAME ];then

			mv working/${MKMINIOS_CODENAME}/$NAME ${MKMINIOS_TARGET}/opt/
			
		fi

			# create .opt file
			cd  ${MKMINIOS_TARGET}/opt/
			$MKSQF $NAME $NAME.opt -noappend 
			cd -
			
			# move opt directory out from rootfs
			mv ${MKMINIOS_TARGET}/opt/$NAME working/${MKMINIOS_CODENAME}/
		
		cd ${MKMINIOS_TARGET}
			# create the cpio.gz format file to be loaded at boot
			find opt/$NAME.opt | cpio -H newc -o | gzip -9 > ../../../deploy/${MKMINIOS_CODENAME}/$NAME
			# clean up .opt file 
			rm -f opt/$NAME.opt
		cd -
		
	done
	
	# create compressed rootfs to /opt/rootfs.sqf 
	[ -d working/${MKMINIOS_CODENAME}/initramfs/opt ] || mkdir -p working/${MKMINIOS_CODENAME}/initramfs/opt
	$MKSQF ${MKMINIOS_TARGET}/ working/${MKMINIOS_CODENAME}/initramfs/opt/rootfs.sqf -noappend 


	## FIXME: use variable instead of actual initramfs path
	cd working/${MKMINIOS_CODENAME}/initramfs
	find | cpio -H newc -o > ../../../deploy/${MKMINIOS_CODENAME}.cpio
	cd -

	for format in `./tools/parser ${MKMINIOS_CONFIG} image`; do 
	
	case $format in
			gz)
				cat deploy/${MKMINIOS_CODENAME}.cpio | gzip -9 > deploy/${MKMINIOS_CODENAME}/initrd.img
				du -h deploy/${MKMINIOS_CODENAME}/initrd.img
			;;
			iso)
				cp -r skeleton/boot/iso/ deploy/${MKMINIOS_CODENAME}/
				cp ${MKMINIOS_KERNEL_IMAGE} deploy/${MKMINIOS_CODENAME}/iso/boot/kernel
				cp deploy/${MKMINIOS_CODENAME}/initrd.img deploy/${MKMINIOS_CODENAME}/iso/boot/initrd.img
#				cp deploy/${MKMINIOS_CODENAME}/system.img deploy/${MKMINIOS_CODENAME}/iso/boot/system.img
#				cp deploy/${MKMINIOS_CODENAME}/*.opt deploy/${MKMINIOS_CODENAME}/iso/boot/opt/
				mkisofs -R -l -V 'StarOS' -input-charset utf-8 -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -o deploy/${MKMINIOS_CODENAME}.iso deploy/${MKMINIOS_CODENAME}/iso/
				rm -rf deploy/${MKMINIOS_CODENAME}/iso/
				./tools/isohybrid deploy/${MKMINIOS_CODENAME}.iso
				du -h deploy/${MKMINIOS_CODENAME}.iso
			;;
			*)
			echo "$format: not supported format"
			;;
	esac 
	done

}

# create standalone opt package from recipe or directory (if recipe was not found)
function makeopt {
	if [ ! -z $2 ] && [ -f "config/$2.cookbook" ]; then export MKMINIOS_CODENAME=$2
	 else export MKMINIOS_CODENAME='default'; fi
	export MKMINIOS_TARGET=working/${MKMINIOS_CODENAME}/rootfs
	export OPT_PKG=$1
	# check if recipe exists
	if [ ! -z $OPT_PKG ] && [ -f "package/recipe/$OPT_PKG.recipe" ]; then
		echo "Creating standalone opt package $OPT_PKG for ${MKMINIOS_CODENAME}"
		# download required packages
		echo "Downloading required packages"
		for P in `./tools/parser package/recipe/$OPT_PKG.recipe package`; do
			PACKAGE="$PACKAGE $P"
		done
		if [ "$MKMINIOS_PKGMGR" != 'skip' ]; then
			$MKMINIOS_PKGMGR $PACKAGE
		else 
			echo "You need to install following packages according to your cookbook: "
			echo "$PACKAGE"
		fi
		echo "Using recipe, copying files"
		# create opt directory
		NAME=`./tools/parser package/recipe/$OPT_PKG.recipe name`
		# cleanup working opt directory
		rm -rf ${MKMINIOS_TARGET}/opt/$NAME deploy/opt/${MKMINIOS_CODENAME}/$NAME.opt
		mkdir -p ${MKMINIOS_TARGET}/opt/$NAME
		# action 
		eval `./tools/parser package/recipe/$OPT_PKG.recipe action`
		# copy files
		echo "Copying files"
		for S in binary data config overwrite; do
			for A in `./tools/parser package/recipe/$OPT_PKG.recipe $S`; do
				copyfiles $S ${MKMINIOS_TARGET}/opt/$NAME $A
			done
		done
		# post action 
		eval `./tools/parser package/recipe/$OPT_PKG.recipe post_action`
		# check dependencies
		echo "Checking dependencies..."
		find ${MKMINIOS_TARGET}/opt/$NAME/ -type f | while read s
		do
			copydeps "$s" ${MKMINIOS_TARGET}/opt/$NAME
		done
		SOURCE_DIR=${MKMINIOS_TARGET}/opt/$NAME
		TARGET_OPT=deploy/opt/${MKMINIOS_CODENAME}/$NAME
	else
		# create opt from directory
		if [ -d $OPT_PKG ]; then
			echo "Creating opt from directory"
			SOURCE_DIR=$OPT_PKG
			TARGET_OPT=deploy/opt/`basename $OPT_PKG`
		else
			echo "Error - please specify recipe file or directory."
			exit;
		fi
	fi
	# temporary hook for squashfs version 
	if [ -e /usr/bin/mksquashfs ]; then 
		MKSQF="mksquashfs" 
	else 
		echo "Error - not found mksquashfs."
		exit;
	fi
	
	mkdir -p deploy/opt/${MKMINIOS_CODENAME}
	$MKSQF $SOURCE_DIR $TARGET_OPT.opt -noappend
	
	echo "Complete!"
}
