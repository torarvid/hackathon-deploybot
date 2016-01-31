#!/bin/sh

set -e

usage() {
	echo "Usage: $0 staging|prod"
	exit 2
}

if [ $# -lt 1 ]; then
	usage
fi

TARGET_ENV=$1
LOG=/logs/${TARGET_ENV}.log
: > $LOG

log()
{
	DATE=$(date)
	echo "[${DATE}]: $1" >> $LOG
}

log "Starting deployment of $TARGET_ENV"

if [ "$TARGET_ENV" = "staging" ]; then
	BASEDIR=deployment/dogebox
	PARAMS="--params ../../secrets/dogebox/nova-params.yml"
	BUILD=dogebox
	DEPLOY=dogebox/app-nonexist
elif [ "$TARGET_ENV" = "prod" ]; then
	BASEDIR=deployment
	PARAMS="--params params/production.yml --params ../secrets/nova-params/production-secrets.yml"
	BUILD=wowbox
	DEPLOY=wowbox/app-1
else
	log "Usage: $0 staging|prod"
	exit 2
fi

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
nova --profile $TARGET_ENV $PARAMS --verbose build $BUILD
log "Nova build done. Now deploying (will take a while)"
nova --profile $TARGET_ENV $PARAMS --verbose --output-format text deploy --wait $DEPLOY
log "Nova deploy done. Did it work?!?!"
