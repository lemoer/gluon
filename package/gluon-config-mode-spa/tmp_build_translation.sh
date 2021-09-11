#!/bin/sh
find package/gluon-web* package/gluon-config-* -name de.po | xargs msgcat > package/gluon-config-mode-spa/files/lib/gluon/config-mode/www/config-spa/i18n/de.po
find package/gluon-web* package/gluon-config-* -name fr.po | xargs msgcat > package/gluon-config-mode-spa/files/lib/gluon/config-mode/www/config-spa/i18n/fr.po
