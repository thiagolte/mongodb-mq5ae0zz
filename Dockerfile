FROM mongo:8.0

# Enable Render SSH / Shell access for this Docker image.
# See: https://render.com/docs/ssh#docker-specific-configuration
#
# Root cause of "Connection closed by remote host" right after auth:
# The official mongo image sets `ENV HOME /data/db` (so mongosh has a valid
# HOME). The mongod process runs as the "mongodb" user (via gosu), so the
# running user's $HOME is /data/db -- which is exactly where Render mounts the
# persistent disk. Render does NOT allow the persistent disk to be mounted at
# the running user's $HOME, so it accepts the key but immediately closes the
# shell session.
#
# Fix:
#   1. Override HOME to a path that is NOT on the persistent disk.
#   2. Create that home dir + a ~/.ssh dir (0700), owned by mongodb, so both
#      mongosh and the SSH session have a valid, writable home.
#   3. Give both mongodb and root a real login shell (/bin/bash).
#   4. Unlock root (Render does not allow the root account to be locked).
#
# mongod keeps using /data/db as its dbpath (the default / CMD argument), which
# is independent of $HOME, so the database is unaffected.
USER root

ENV HOME=/home/mongodb

RUN mkdir -p /home/mongodb/.ssh \
    && chmod 0700 /home/mongodb/.ssh \
    && usermod -s /bin/bash -d /home/mongodb mongodb \
    && chown -R mongodb:mongodb /home/mongodb \
    && usermod -s /bin/bash root \
    && mkdir -p /root/.ssh \
    && chmod 0700 /root/.ssh \
    && usermod -p '*' root \
    && usermod -p '*' mongodb
