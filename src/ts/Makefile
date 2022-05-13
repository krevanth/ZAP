SUBDIRS := $(wildcard */.)
CORES   := $(shell getconf _NPROCESSORS_ONLN)

ifdef TC
all:
	cd $(TC) && $(MAKE) TC=$(TC)
else
all: $(SUBDIRS)
$(SUBDIRS):
	cd $@ && $(MAKE)
endif

clean:
	rm -rfv ../../obj/

.PHONY: all $(SUBDIRS) clean
