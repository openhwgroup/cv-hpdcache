#!/bin/bash -x
##
#  Copyright 2024 Cesar Fuguet
#  Copyright 2025 Inria
#
#  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
##
#  Author     : Cesar Fuguet
#  Date       : October, 2024
#  Description: Environment setup for the HPDcache's Github CI
##
export WORK_DIR=${PWD}
export BUILD_DIR=${WORK_DIR}/build
export ARCHIVE_DIR=${WORK_DIR}/archive
export PARALLEL_JOBS=7

mkdir -p ${ARCHIVE_DIR} ${BUILD_DIR} ;

#  OSS-CAD-Suite env variables
export OSS_CAD_SUITE_VER=2026-05-29
export OSS_CAD_SUITE_URL=https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_VER}/oss-cad-suite-linux-x64-${OSS_CAD_SUITE_VER//-/}.tgz
export OSS_CAD_SUITE_ROOT=${BUILD_DIR}/oss-cad-suite

if [[ -e ${OSS_CAD_SUITE_ROOT}/environment ]] ; then
    . ${OSS_CAD_SUITE_ROOT}/environment ;
fi
