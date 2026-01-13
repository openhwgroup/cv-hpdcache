#!/bin/bash -x
##
#  Copyright 2025 Inria
#  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
##
#  Author       Cesar Fuguet
#  Date         June, 2025
#  Description  OSS-CAD-Suite installation script
##

#  Install OSS-CAD-Suite
if [[ "x${OSS_CAD_SUITE_ROOT}" == "x" ]] ; then
   echo "OSS_CAD_SUITE_ROOT env variable not defined" ;
   exit 1 ;
fi

oss_cad_suite_installed="no"
if [[ -d ${OSS_CAD_SUITE_ROOT} ]] ; then
   echo "OSS-CAD-Suite is already installed" ;
   oss_cad_suite_installed="yes" ;
fi

if [[ "x${OSS_CAD_SUITE_VER}" == "x" ]] ; then
   echo "OSS_CAD_SUITE_VER env variable not defined" ;
   exit 1 ;
fi

if [[ "x${OSS_CAD_SUITE_URL}" == "x" ]] ; then
   echo "OSS_CAD_SUITE_URL env variable not defined" ;
   exit 1 ;
fi

#  get OSS-CAD-Suite
if [[ ${oss_cad_suite_installed} == "no" ]] ; then
(
    wget -O ${ARCHIVE_DIR}/oss-cad-suite-${OSS_CAD_SUITE_VER}.tgz \
        ${OSS_CAD_SUITE_URL} ;
    tar xzf ${ARCHIVE_DIR}/oss-cad-suite-${OSS_CAD_SUITE_VER}.tgz ;
    mv -f oss-cad-suite ${OSS_CAD_SUITE_ROOT} ;
)
fi
