SUBDIRS := $(wildcard */.)

all: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@

clean:
	rm -rfv ../../obj/

.PHONY: all $(SUBDIRS) clean
