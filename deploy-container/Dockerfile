
FROM node:4
MAINTAINER Tor Arvid Lund <torarvid@telenordigital.com>

ENV AWS_ACCESS_KEY_ID replaceme
ENV AWS_SECRET_ACCESS_KEY replaceme

RUN groupadd -r nodejs && useradd -r -g nodejs nodejs

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg2 \
    && curl -o /usr/local/bin/gosu -SL 'https://github.com/tianon/gosu/releases/download/1.1/gosu' \
    && chmod +x /usr/local/bin/gosu \
    && apt-get purge -y --auto-remove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/tmp/*

WORKDIR /var/app

ADD wowbox.tar.xz /var/app/

ADD nova /var/app/nova
RUN cd nova/novaform && npm link
RUN cd nova/novastl && npm link novaform && npm link
RUN cd nova/nova && npm link novaform && npm link novastl && npm link
ADD novacfg /root/.novacfg

VOLUME [ "/secrets", "/logs", "/config" ]

# Avoid interactive yes/no question when doing git-clone
RUN mkdir ~/.ssh
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts

ADD blackbox/* /usr/local/bin/
ADD clone.sh /var/app/
ADD deploy.sh /var/app/
ADD deploy /var/app/deploy
