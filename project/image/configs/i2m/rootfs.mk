IMAGE_INSTALL_DIR:=$(OUTPUTDIR)
#-include $(PROJ_ROOT)/../sdk/verify/application/app.mk
#-include $(PROJ_ROOT)/release/customer_tailor/$(CUSTOMER_TAILOR)

LIB_DIR_PATH:=$(PROJ_ROOT)/release/$(PRODUCT)/$(CHIP)/common/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)

.PHONY: rootfs root app
rootfs:root app
root:
	cd rootfs; tar xf rootfs.tar.gz -C $(OUTPUTDIR)
	rm $(OUTPUTDIR)/rootfs/etc/init.d/S80dhcp-server
	rm $(OUTPUTDIR)/rootfs/etc/init.d/S80dhcp-relay
	rm $(OUTPUTDIR)/rootfs/etc/init.d/S50mosquitto
	rm $(OUTPUTDIR)/rootfs/etc/init.d/S41dhcpcd
	cp rootfs_add_files/etc/init.d/S50sshd $(OUTPUTDIR)/rootfs/etc/init.d/S50sshd
	sed -i 's/\#PermitRootLogin prohibit-password/PermitRootLogin yes/' $(OUTPUTDIR)/rootfs/etc/ssh/sshd_config

	if [ -d "firmware" ]; then \
	   cp firmware/* /root/ -rf ;\
	fi;

	# foe no login
	sed -i 's/console\:\:respawn\:\/sbin\/getty -L  console 0 vt100 \# GENERIC_SERIAL/console::respawn:-\/bin\/sh/' $(OUTPUTDIR)/rootfs/etc/inittab
	#tar xf busybox/$(BUSYBOX).tar.gz -C $(OUTPUTDIR)/rootfs
	tar xf $(LIB_DIR_PATH)/package/$(LIBC).tar.gz -C $(OUTPUTDIR)/rootfs/lib
	mkdir -p $(miservice$(RESOUCE))/lib
	cp $(LIB_DIR_PATH)/mi_libs/dynamic/* $(miservice$(RESOUCE))/lib/
	cp $(LIB_DIR_PATH)/ex_libs/dynamic/* $(miservice$(RESOUCE))/lib/
	
	mkdir -p $(miservice$(RESOUCE))
	if [ "$(BOARD)" = "010A" ]; then \
		cp -rf $(PROJ_ROOT)/board/ini/* $(miservice$(RESOUCE)) ;\
	else \
		cp -rf $(PROJ_ROOT)/board/ini/LCM $(miservice$(RESOUCE)) ;\
	fi;

	if [ "$(BOARD)" = "010A" ]; then \
		cp -rf $(PROJ_ROOT)/board/$(CHIP)/$(BOARD_NAME)/config/* $(miservice$(RESOUCE)) ; \
	else \
		cp -rf $(PROJ_ROOT)/board/$(CHIP)/$(BOARD_NAME)/config/fbdev.ini  $(miservice$(RESOUCE)) ; \
	fi;

	cp -vf $(PROJ_ROOT)/board/$(CHIP)/mmap/$(MMAP)  $(miservice$(RESOUCE))/mmap.ini
	cp -rvf $(LIB_DIR_PATH)/bin/config_tool/*  $(miservice$(RESOUCE))
	cd  $(miservice$(RESOUCE)); chmod +x config_tool; ln -sf config_tool dump_config; ln -sf config_tool dump_mmap
	if [ "$(BOARD)" = "010A" ]; then \
		cp -rf $(PROJ_ROOT)/board/$(CHIP)/pq  $(miservice$(RESOUCE))/ ; \
		find   $(miservice$(RESOUCE))/pq/ -type f ! -name "Main.bin" -type f ! -name "Main_Ex.bin" -type f ! -name "Bandwidth_RegTable.bin"| xargs rm -rf ; \
	fi;

	mkdir -p $(OUTPUTDIR)/rootfs/config
	if [ "$(appconfigs$(RESOUCE))" != "" ]; then \
		mkdir -p  $(appconfigs$(RESOUCE)); \
		mkdir -p $(OUTPUTDIR)/rootfs/appconfigs;\
	fi;

	mkdir -p $(OUTPUTDIR)/rootfs/lib/modules/
	mkdir -p  $(miservice$(RESOUCE))/modules/$(KERNEL_VERSION)

	touch ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo mice 0:0 0660 =input/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo mouse.* 0:0 0660 =input/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo event.* 0:0 0660 =input/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	# for alsa
	echo pcm.* 0:0 0660 =snd/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo control.* 0:0 0660 =snd/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo timer 0:0 0660 =snd/ >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo '$$DEVNAME=bus/usb/([0-9]+)/([0-9]+) 0:0 0660 =bus/usb/%1/%2'>> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo sd[a-z][0-9]  0:0  660  @/etc/hotplug/udisk_insert >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo sd[a-z]       0:0  660  \$$/etc/hotplug/udisk_remove >> ${OUTPUTDIR}/rootfs/etc/mdev.conf 	
	echo mmcblk[0-9]p[0-9]  0:0  660  @/etc/hotplug/sdcard_insert >> ${OUTPUTDIR}/rootfs/etc/mdev.conf
	echo mmcblk[0-9]        0:0  660   \$$/etc/hotplug/sdcard_remove >> ${OUTPUTDIR}/rootfs/etc/mdev.conf

	echo export PATH=\$$PATH:/config >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo export TERMINFO=/config/terminfo >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo export LD_LIBRARY_PATH=\$$LD_LIBRARY_PATH:/config/lib:/config/wifi >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo export LD_LIBRARY_PATH=\$$LD_LIBRARY_PATH:/config/lib:/config/wifi >> ${OUTPUTDIR}/rootfs/etc/profile
	sed -i '/^mount.*/d' $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mkdir -p /dev/pts >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS
	echo mount -t sysfs none /sys >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mount -t tmpfs mdev /dev >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mount -t debugfs none /sys/kernel/debug/ >>  $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	echo mdev -s >> $(OUTPUTDIR)/rootfs/etc/init.d/rcS
	cp -rvf $(PROJ_ROOT)/tools/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)/fw_printenv/* $(OUTPUTDIR)/rootfs/etc/
	echo "$(ENV_CFG)" > $(OUTPUTDIR)/rootfs/etc/fw_env.config
	if [ "$(ENV_CFG1)" != "" ]; then \
		echo "$(ENV_CFG1)" >> $(OUTPUTDIR)/rootfs/etc/fw_env.config ; \
	fi;
	cd $(OUTPUTDIR)/rootfs/etc/;ln -sf fw_printenv fw_setenv
	echo mkdir -p /var/lock >> ${OUTPUTDIR}/rootfs/etc/init.d/rcS

	chmod 755 $(LIB_DIR_PATH)/bin/debug/*
	cp -rf $(LIB_DIR_PATH)/bin/debug/*  $(miservice$(RESOUCE))
	mkdir -p $(OUTPUTDIR)/customer

	ln -fs /config/modules/$(KERNEL_VERSION) $(OUTPUTDIR)/rootfs/lib/modules/
	#find $(OUTPUTDIR)/rootfs/lib/ -name "*.so*" | xargs $(TOOLCHAIN_REL)strip  --strip-unneeded;
	find $(OUTPUTDIR)/rootfs/lib/ -name "*.so*" -a -name "*[!p][!y]" | xargs $(TOOLCHAIN_REL)strip  --strip-unneeded;
	
	if [ $(TOOLCHAIN) = "glibc" ]; then \
		cp -rvf $(PROJ_ROOT)/tools/$(TOOLCHAIN)/$(TOOLCHAIN_VERSION)/htop/terminfo $(OUTPUTDIR)/miservice/config/;	\
	fi;
	
	mkdir -p $(OUTPUTDIR)/vendor
	mkdir -p $(OUTPUTDIR)/customer
	mkdir -p $(OUTPUTDIR)/rootfs/vendor
	mkdir -p $(OUTPUTDIR)/rootfs/customer	
