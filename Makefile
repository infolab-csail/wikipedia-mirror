# This takes care of providing targets for overhead stuff like
# creating directories, pulling repositories, kickstarting a new
# server if you have a running one available etc. Much of the code in
# here was taken from
#
# http://github.com/fakedrake/xilinx-zynq-bootstrap
#
# This also includes the rest of the makefiles.

MAKETHREADS=4
MAKE=make -j$(MAKETHREADS)
RSYNC=rsync -avz

ifneq ($(REMOTE_SERVER),)
remote-maybe=echo "==== Running on $(REMOTE_SERVER) ====" && ssh $(REMOTE_SERVER) 'PATH=$(PATH) && $1'
else
remote-maybe=echo "==== Running locally ====" && $1
endif

.PHONY: force
force: ;

# My directories
ROOT_DIR=$(PWD)
#Data is part of the repo
DATA_DIR=$(PWD)/data
SOURCES_DIR=$(ROOT_DIR)/sources
DRAFTS_DIR=$(ROOT_DIR)/drafts
TOOLS_DIR=$(ROOT_DIR)/tools
LAZY_DIR=$(ROOT_DIR)/lazy
FILESYSTEM_ROOT=$(ROOT_DIR)/fs

ROOT_DIRECTORIES = $(ROOT_DIR) $(SOURCES_DIR) $(DRAFTS_DIR) $(RESOURCES_DIR) $(TOOLS_DIR) $(LAZY_DIR)

# Filesystem root directories
FSROOT_TMP=$(FILESYSTEM_ROOT)/tmp
FSROOT_BIN=$(FILESYSTEM_ROOT)/bin
FSROOT_USRBIN=$(FILESYSTEM_ROOT)/usr/bin
FSROOT_ETC=$(FILESYSTEM_ROOT)/etc
FSROOT_PROC=$(FILESYSTEM_ROOT)/proc
FSROOT_SYS=$(FILESYSTEM_ROOT)/sys
FSROOT_DEV=$(FILESYSTEM_ROOT)/dev

FSROOT_DIRECTORIES = $(FSROOT_PROC) $(FSROOT_DEV) $(FSROOT_SYS) $(FSROOT_TMP) $(FSROOT_BIN) $(FSROOT_USRBIN) $(FSROOT_ETC)

DIRECTORIES = $(FSROOT_DIRECTORIES) $(ROOT_DIRECTORIES)

# Filesystem root might contain sockets and thus MUST NOT be on afs.
# Only the first afs root found is considered.

# NOTE: This is only to solve the problem of sockets. To solve the
# disk space quota problem move the ROOT_DIR. Also we do not require
# the user to move FILESYSTEM_ROOT by hand because it would add
# unneeded overhead.
AFS_ROOT=$(shell mount -l | grep "AFS" | grep -o "/[^ ]*" | head -1)
ifneq ($(AFS_ROOT),)
ifneq ($(shell echo $(FILESYSTEM_ROOT) | grep "^$(AFS_ROOT)"),)
LOCAL_FSROOT=/scratch/wikipedia_srv/fs
ROOT_DIRECTORIES += $(LOCAL_FSROOT)
$(FILESYSTEM_ROOT): | $(LOCAL_FSROOT)
	@echo "AFS directory detected. Using LOCAL_FSROOT ($(LOCAL_FSROOT))"
	ln -s $(LOCAL_FSROOT) $(FILESYSTEM_ROOT)
else
DIRECTORIES += $(FILESYSTEM_ROOT)
endif
else
DIRECTORIES += $(FILESYSTEM_ROOT)
endif
# KICKSTART_DIR=/some/dir

# Includes should be after command declarations and before targets
include Makefile.xampp
include Makefile.wiki
include Makefile.dumps
include Makefile.bitnami

$(FSROOT_DIRECTORIES): $(FILESYSTEM_ROOT)

$(DIRECTORIES):
	[ -d $@ ] || [ -h $@ ] || mkdir -p $@

# Copy files from KICKSTART_DIR which is tha ROOT_DIR of another
# project to this ROOT_DIR with rsync. This saves computation time and
# bandwidth. KICKSTART_DIR can be remote.
kickstart: kickstart-sources kickstart-drafts

kickstart-%:
	$(RSYNC) $(KICKSTART_DIR)/$* $(ROOT_DIR)/$*

show-projects:
	@echo "Git Projects: $(GIT_PROJECTS)"
	@echo "Archive Projects: $(TAR_PROJECTS)"
	@echo "Raw projects: $(RAW_PROJECTS)"
	@echo "Bzip projects: $(BZ_PROJECTS)"
	@echo "Gzip projects: $(GZ_PROJECTS)"

# Generate targets for pulling stuff from the interwebnets. I will
# show you how to use those with examples. Repos and extracted code
# goes into SOURCES_DIR

## GIT
# <prj-name>-git-repo = <git repo url>
# GIT_PROJECTS += <prj-name>
# <prj-name>-build: <prj-name>
.SECONDEXPANSION :
$(GIT_PROJECTS) : $(SOURCES_DIR)/$$@-git

$(SOURCES_DIR)/%-git : force
	$(call remote-maybe, if [ ! -d $@ ]; then \
		git clone $($*-git-repo) $@ ;\
		if [ "$($*-git-commit)" != "" ]; then git checkout $($*-git-commit); fi; \
	fi)
	$(call remote-maybe, cd $@ && git pull)

%-git-purge:
	$(call remote-maybe, rm -rf $(SOURCES_DIR)/$*-git)

%-git-clean:
	$(call remote-maybe, cd $(SOURCES_DIR)/$*-git && $(MAKE) clean)

%-git-distclean:
	$(call remote-maybe, cd $(SOURCES_DIR)/$*-git && $(MAKE) distclean)

## Tar archives
# <prj-name>-tar-url = <tar url>
# TAR_PROJECTS += <prj-name>
# <prj-name>-build: <prj-name>

## The project has never existed:
# $ make <prj-name>-tar-clean

.SECONDEXPANSION :
$(TAR_PROJECTS) :  $(SOURCES_DIR) $(SOURCES_DIR)/$$@-tar

.SECONDARY:
$(DRAFTS_DIR)/%.tar.gz: | $(DRAFTS_DIR)
	echo "Pulling tar project $*."
	wget $($*-tar-url) -O $@

.SECONDEXPANSION :
$(SOURCES_DIR)/%-tar : | $(DRAFTS_DIR)/$$*.tar.gz
	mkdir $@
	cd $@ && tar xvzf $(DRAFTS_DIR)/$*.tar.gz

%-tar-clean:
	rm -rf $(SOURCES_DIR)/$*-tar $(DRAFTS_DIR)/$*.tar.gz


## Bz2 archives
# <prj-name>-bz-url = <tar url>
# BZ_PROJECTS += <prj-name>
# <prj-name>-build: <prj-name>

## The project has never existed:
# $ make <prj-name>-bz-clean

.SECONDEXPANSION :
$(BZ_PROJECTS) :  $(SOURCES_DIR) $(SOURCES_DIR)/$$@-bz

.SECONDARY:
$(DRAFTS_DIR)/bz-%.bz2: | $(DRAFTS_DIR)
	echo "Pulling bz2 project $*."
	wget $($*-bz-url) -O $@

.SECONDEXPANSION :
$(SOURCES_DIR)/%-bz : | $(DRAFTS_DIR)/bz-$$*.bz2
	mkdir $@
	cd $@ && bzcat -dv $(DRAFTS_DIR)/bz-$*.bz2 > $*

%-bz-clean:
	rm -rf $(SOURCES_DIR)/$*-bz $(DRAFTS_DIR)/bz-$*.bz2

## GZ archives
# <prj-name>-gz-url = <gz url>
# GZ_PROJECTS += <prj-name>
# <prj-name>-build: <prj-name>

## The project has never existed:
# $ make <prj-name>-gz-clean
.SECONDEXPANSION :
$(GZ_PROJECTS) :  $(SOURCES_DIR) $(SOURCES_DIR)/$$@-gz

.SECONDARY:
$(DRAFTS_DIR)/gz-%.gz: | $(DRAFTS_DIR)
	echo "Pulling gz project $*."
	wget $($*-gz-url) -O $@

.SECONDEXPANSION :
$(SOURCES_DIR)/%-gz : | $(DRAFTS_DIR)/gz-$$*.gz
	mkdir $@
	cd $@ && gzip -dc $(DRAFTS_DIR)/gz-$*.gz > $*

%-gz-clean:
	rm -rf $(SOURCES_DIR)/$*-gz $(DRAFTS_DIR)/gz-$*.gz


## Raw binaries
# <prj-name>-raw-url = <binary url>
# RAW_PROJECTS += <prj-name>
# <prj-name>-build: <prj-name>

# Raw projects are projects that do not need to be extracted in any
# way.
# Note: $(DRAFTS_DIR)/raw-<prj-name> is the name of the local binary file.
$(RAW_PROJECTS) :  $(DRAFTS_DIR)/raw-$$@

$(DRAFTS_DIR)/raw-% : | $(DRAFTS_DIR)
	echo "Pulling raw project $*"
	wget $($*-raw-url) -O $@

# Lazies
#
# So that we do not configure everything over and over, I touch
# something in lazy/ and you want to remove it to run lazy
# dependencies.
#
# I will just do lazies locally for no particular reasons

# Running <target>-lazy will actually run <target>-build

.SECONDEXPANSION:
$(LAZY_DIR)/%: $(LAZY_DIR) $$*-build
	touch $@

.SECONDEXPANSION:
%-lazy: $(LAZY_DIR)/$$*
	echo "Lazy $@, createing $(LAZY_DIR)/$*"

.SECONDEXPANSION:
%-shallow-lazy:
	echo "Avoiding build, just creating $^"
	touch $(LAZY_DIR)/$*

%-clean-lazy:
	rm -rf $(LAZY_DIR)/$*

all-clean-lazy:
	rm -rf $(LAZY_DIR)
