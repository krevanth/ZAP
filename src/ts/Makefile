SUBDIRS := $(wildcard */.)
CORES   := $(shell getconf _NPROCESSORS_ONLN)

ifdef TC
all:
	cd $(TC) && $(MAKE) TC=$(TC) -j $(CORES)
else
all: $(SUBDIRS)
$(SUBDIRS):
	cd $@ && $(MAKE) -j $(CORES)
endif

clean:
	rm -rfv ../../obj/

.PHONY: all $(SUBDIRS) clean
