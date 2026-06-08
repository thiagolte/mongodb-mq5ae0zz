FROM mongo:8.0

# Enable Render SSH / Shell access for this Docker image.
# See: https://render.com/docs/ssh#docker-specific-configuration
#
# The official mongo image starts as "root", but its entrypoint drops
# privileges at runtime and runs mongod as the "mongodb" user (via gosu).
# Critically, the image creates the "mongodb" user with its $HOME set to
# /data/db, which is exactly where Render mounts the persistent disk. Render
# does NOT support SSH when the persistent disk is mounted at the running
# user's $HOME, which is why SSH connections to this service are refused.
#
# To fix this we:
#   1. Move the mongodb user's home directory off the disk (to /home/mongodb).
#      We do NOT use `usermod -m` so the existing /data/db contents are left
#      untouched. mongod keeps using /data/db as its dbpath (passed as an
#      argument), so this does not affect the database.
#   2. Give both root and mongodb a real login shell (/bin/bash).
#   3. Create a ~/.ssh directory (0700) for both users.
#   4. Unlock root, since Render does not allow the root account to be locked.
#
# Note: the mongo image does not run its own SSH server (nothing listens on
# port 22), as required by Render.
USER root

RUN (usermod --unlock root || passwd -u root || true) \
    && usermod -s /bin/bash root \
    && mkdir -p /root/.ssh \
    && chmod 0700 /root/.ssh \
    && (usermod --unlock mongodb || passwd -u mongodb || true) \
    && usermod -s /bin/bash -d /home/mongodb mongodb \
    && mkdir -p /home/mongodb/.ssh \
    && chmod 0700 /home/mongodb/.ssh \
    && chown -R mongodb:mongodb /home/mongodb
