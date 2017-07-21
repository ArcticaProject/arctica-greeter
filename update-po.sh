#!/bin/bash

set -x

GETTEXT_DOMAIN=$(cat configure.ac | grep -E "^GETTEXT_PACKAGE=" | sed -e 's/GETTEXT_PACKAGE=//')

cd po/
cat LINGUAS | while read lingua; do touch ${lingua}.po; intltool-update --gettext-package ${GETTEXT_DOMAIN} $(basename ${lingua}); done
cd - 1>/dev/null
