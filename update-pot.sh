#!/bin/bash

GETTEXT_DOMAIN=$(cat configure.ac | grep -E "^GETTEXT_PACKAGE=" | sed -e 's/GETTEXT_PACKAGE=//')

cd po/ && intltool-update --gettext-package ${GETTEXT_DOMAIN} --pot
