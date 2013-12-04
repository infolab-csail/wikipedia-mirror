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

FSROOT_DIRECTORIES = $(FSROOT_TMP)

DIRECTORIES = $(FSROOT_DIRECTORIES) $(ROOT_DIRECTORIES)

# Includes should be after command declarations and before targets
include Makefile.xampp
include Makefile.wiki

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
	$(call remote-maybe, if [ ! -d $@ ] || "$(force-$*-clone)" then; \
		git clone $($*-git-repo) $@ \
		if [ "$($*-git-commit)" != "" ] then; git checkout $($*-git-commit); fi \
	fi)
	$(call remote-maybe, @cd $@ && git pull)

%-git-purge:
	$(call remote-maybe, rm -rf $(SOURCES_DIR)/$*-git)

%-clean:
	$(call remote-maybe, cd $(SOURCES_DIR)/$*-git && $(MAKE) clean)

%-distclean:
	$(call remote-maybe, cd $(SOURCES_DIR)/$*-git && $(MAKE) distclean)

# For zip archives we need a url to the zip archive an the path from
# the zip root to the project root.
.SECONDEXPANSION :
$(TAR_PROJECTS) :  $(SOURCES_DIR) $(SOURCES_DIR)/$$@-archive

.SECONDARY:
$(DRAFTS_DIR)/%.tar.gz: | $(DRAFTS_DIR)
	echo "Pulling tar project $*."
	wget $($*-tar-url) -O $@

.SECONDEXPANSION :
$(SOURCES_DIR)/%-archive : | $(DRAFTS_DIR)/$$*.tar.gz
	mkdir $@
	cd $@ && tar xvzf $(DRAFTS_DIR)/$*.tar.gz

%-clean-archive:
	rm -rf $(SOURCES_DIR)/$*-archive $(DRAFTS_DIR)/$*.tar.gz

# Raw projects are projects that do not need to be extracted in any way.
$(RAW_PROJECTS) :  $(DRAFTS_DIR)/raw-$$@ | $(DRAFTS_DIR)

$(DRAFTS_DIR)/raw-% :
	echo "Pulling raw project $*."
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
