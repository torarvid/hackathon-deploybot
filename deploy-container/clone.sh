#!/bin/sh

if [ -z "$SSH_AUTH_SOCK" ]; then
	eval $(ssh-agent)
fi
ssh-add /secrets/wowbot

git clone ssh://git@github.com/comoyo/wowbox
