#!/bin/sh

_PATH=$PATH

which appledoc &> /dev/null
if [[ $? == 1 ]]; then
	PATH=$PATH:/usr/local/bin
	which appledoc &> /dev/null
	if [[ $? == 1 ]]; then
		echo "Appledoc was not found. Try installing it by 'make install-appledoc'."
		exit 127
	fi
fi

appledoc \
 	--project-name 'SocketClient' \
 	--project-version $(cat VERSION) \
	--project-company 'redpixtec. GmbH' \
	--company-id 'com.paij' \
	--no-warn-invalid-crossref \
	--logformat xcode \
	--output build/doc \
	--create-html \
	--keep-intermediate-files \
	--create-docset \
	--install-docset \
	--publish-docset \
	--index-desc README.md \
	--docset-bundle-id com.paij.SocketClient \
	--docset-bundle-name SocketClient \
	--docset-feed-url 'http://mrackwitz.github.io/SocketClient/doc/com.paij.SocketClient.atom' \
	--docset-package-url 'com.paij.SocketClient' \
	--docset-publisher-name paij  \
	--docset-platform-family iOS \
	--ignore build \
	--ignore pages \
	.

PATH=$_PATH
