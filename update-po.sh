#!/bin/bash

set -x

# Copyright (C) 2017 by Mike Gabriel <mike.gabriel@das-netzwerkteam.de>
#
# This package is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 3 of the License.
#
# This package is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>

GETTEXT_DOMAIN=$(cat configure.ac | grep -E "^GETTEXT_PACKAGE=" | sed -e 's/GETTEXT_PACKAGE=//')

cd po/
cat LINGUAS | while read lingua; do
	if [ ! -e ${lingua}.po ]; then
		msginit --input=${GETTEXT_DOMAIN}.pot --locale=${lingua} --no-translator --output-file=$lingua.po
	else
		intltool-update --gettext-package ${GETTEXT_DOMAIN} $(basename ${lingua})
	fi
done
cd - 1>/dev/null
