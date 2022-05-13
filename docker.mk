# // -----------------------------------------------------------------------------
# // --                                                                         --
# // --     (C) 2022 Erez Binyamin(ErezBinyamin), Revanth Kamaraj(krevanth)     --
# // --                                                                         -- 
# // -- --------------------------------------------------------------------------
# // --                                                                         --
# // -- This program is free software; you can redistribute it and/or           --
# // -- modify it under the terms of the GNU General Public License             --
# // -- as published by the Free Software Foundation; either version 2          --
# // -- of the License, or (at your option) any later version.                  --
# // --                                                                         --
# // -- This program is distributed in the hope that it will be useful,         --
# // -- but WITHOUT ANY WARRANTY; without even the implied warranty of          --
# // -- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           --
# // -- GNU General Public License for more details.                            --
# // --                                                                         --
# // -- You should have received a copy of the GNU General Public License       --
# // -- along with this program; if not, write to the Free Software             --
# // -- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA           --
# // -- 02110-1301, USA.                                                        --
# // --                                                                         --
# // -----------------------------------------------------------------------------
# // This bash script will run all the provided ZAP tests in docker.            --
# // -----------------------------------------------------------------------------

IMAGE_TAG=local/zap
CORES    =$(shell getconf _NPROCESSORS_ONLN)

.PHONY: all
.PHONY: clean

all: .image_build test

test:
ifdef TC
	docker run -it -v `pwd`:`pwd` $(IMAGE_TAG) $(MAKE) TC=$(TC) -C `pwd`/src/ts
else
	docker run -it -v `pwd`:`pwd` $(IMAGE_TAG) $(MAKE) -C `pwd`/src/ts
endif

.image_build: Dockerfile
	docker build --no-cache --rm --tag $(IMAGE_TAG) .
	touch .image_build

clean:
	rm -f .image_build
	docker image rmi -f $(IMAGE_TAG)
