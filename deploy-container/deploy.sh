#!/bin/bash

set -e

usage() {
	echo "Usage: $0 staging|prod <component>"
	exit 2
}

if [ $# -lt 2 ]; then
	usage
fi

TARGET_ENV=$1
COMPONENT=${2//\//-}
LOG=/logs/${TARGET_ENV}-${COMPONENT}.log
: > $LOG

log()
{
	DATE=$(date)
	echo "[${DATE}]: $1" >> $LOG
}

log "Starting deployment of '${TARGET_ENV}'-'${COMPONENT}'"

if [ -z "$SSH_AUTH_SOCK" ]; then
	log "Starting ssh-agent"
	eval $(ssh-agent)
	export SSH_AUTH_SOCK
fi
ssh-add /secrets/wowbot

log "Updating the wowbox repo"
cd /var/app/wowbox
git remote | grep gh >/dev/null || git remote add gh ssh://git@github.com/comoyo/wowbox
git fetch gh
git rebase gh/master
npm i
log "Repo up to date. Now decrypting zecretz"

cp /secrets/secring.gpg /root/.gnupg/
if [ -z "$GPG_AGENT_INFO" ]; then
	log "Starting gpg-agent"
	eval $(gpg-agent --daemon --allow-preset-passphrase)
	export GPG_AGENT_INFO
fi

# This is the fingerprint of the subkey (gpg2 --fingerprint --fingerprint wowbot@telenordigital.com)
FINGERPRINT=392BF34F3891F66BEE801DDDDECFC5F67CDA8081
cat /secrets/gpg-passphrase | /usr/lib/gnupg2/gpg-preset-passphrase --preset $FINGERPRINT
blackbox_decrypt_all_files
log "Decrypted... Now running 'nova build'"

cd $BASEDIR
echo nova --profile $TARGET_ENV $PARAMS --verbose build $BUILD
log "Nova build done. Now deploying (will take a while)"
echo nova --profile $TARGET_ENV $PARAMS --verbose --output-format text deploy --wait $DEPLOY
log "Nova deploy done. Did it work?!?!"
