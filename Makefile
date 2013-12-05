MAKETHREADS=4
MAKE=make -j$(MAKETHREADS)

ifneq ($(REMOTE_SERVER),)
remote-maybe=echo "==== Running on $(REMOTE_SERVER) ====" && ssh $(REMOTE_SERVER) 'PATH=$(PATH) && $1'
else
remote-maybe=echo "==== Running locally ====" && $1
endif

.PHONY: force
force: ;

# My directories
ROOT_DIR=$(PWD)
DATA_DIR=$(ROOT_DIR)/data
SOURCES_DIR=$(ROOT_DIR)/sources
DRAFTS_DIR=$(ROOT_DIR)/drafts
TOOLS_DIR=$(ROOT_DIR)/tools
LAZY_DIR=$(ROOT_DIR)/lazy
FILESYSTEM_ROOT=$(ROOT_DIR)/fs

ROOT_DIRECTORIES = $(SOURCES_DIR) $(DRAFTS_DIR) $(RESOURCES_DIR) $(TOOLS_DIR) $(LAZY_DIR) $(FILESYSTEM_ROOT)

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

# Includes should be after command declarations and before targets
include Makefile.xampp
include Makefile.wiki
include Makefile.bitnami

$(FSROOT_DIRECTORIES): | $(FILESYSTEM_ROOT)

$(DIRECTORIES):
	[ -d $@ ] || mkdir -p $@

show-projects:
	@echo "Git Projects: $(GIT_PROJECTS)"
	@echo "Archive Projects: $(TAR_PROJECTS)"
	@echo "Raw projects: $(RAW_PROJECTS)"

# Have repositories
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

# Tar archives
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


# Bz2 archives
.SECONDEXPANSION :
$(BZ_PROJECTS) :  $(SOURCES_DIR) $(SOURCES_DIR)/$$@-bz

.SECONDARY:
$(DRAFTS_DIR)/bz-%.bz2: | $(DRAFTS_DIR)
	echo "Pulling bz2 project $*."
	wget $($*-bz-url) -O $@

.SECONDEXPANSION :
$(SOURCES_DIR)/%-bz : | $(DRAFTS_DIR)/bz-$$*.bz2
	mkdir $@
	cd $@ && bzip2 -dv $(DRAFTS_DIR)/bz-$*.bz2

%-bz-clean:
	rm -rf $(SOURCES_DIR)/$*-bz $(DRAFTS_DIR)/bz-$*.bz2


# Raw projects are projects that do not need to be extracted in any way.
$(RAW_PROJECTS) :  $(DRAFTS_DIR)/raw-$$@ | $(DRAFTS_DIR)

$(DRAFTS_DIR)/raw-% :
	echo "Pulling raw project $*"
	wget $($*-raw-url) -O $@

# Lazies
#
# So that we do not configure everything over and over, I touch
# something in lazy/ and you want to remove it to run lazy
# dependencies.
#
# I will just do lazies locally for no particular reasons
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
