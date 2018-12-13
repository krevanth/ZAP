##################################################
#        (C) 2016-2018 Revanth Kamaraj
##################################################
# This script simply calls Vivado synthesis after
# moving to the OBJ directory. You should run 
# this to start synthesis.
##################################################

mkdir -p ../../../obj/synth/vivado/
cd       ../../../obj/synth/vivado/
vivado -mode batch -source ../../../src/synth/vivado/synth.tcl
cd       ../../../src/synth/vivado/
