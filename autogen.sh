#!/bin/sh
# Run this to generate all the initial makefiles, etc.

srcdir=`dirname $0`
test -z "$srcdir" && srcdir=.

PKG_NAME="arctica-greeter"
REQUIRED_AUTOMAKE_VERSION=1.7

(test -f $srcdir/configure.ac \
  && test -d $srcdir/src) || {
    echo -n "**Error**: Directory "\`$srcdir\'" does not look like the"
    echo " top-level arctica-greeter directory"
    exit 1
}

which mate-autogen || {
    echo "You need to install mate-common from the MATE Desktop Environment"
    exit 1
}
USE_COMMON_DOC_BUILD=yes . mate-autogen
