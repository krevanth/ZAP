#!/bin/bash
if [ -f /.dockerenv ]
then
	ROOT='/ZAP'
else
	ROOT='.'
fi

pushd .
cd ${ROOT}/src/ts/

# arm_test
pushd .
cd ${ROOT}/arm_test
make
popd

popd
