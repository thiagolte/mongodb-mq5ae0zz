FROM mongo:8.0

# Enable Render SSH / Shell access for this Docker image.
# See: https://render.com/docs/ssh#docker-specific-configuration
#
# Root cause of "Connection closed by remote host" right after auth:
#   * The official mongo image NEVER sets a final `USER` instruction, so the
#     image's configured user is root. Render opens the SSH shell as the image's
#     configured user (root) -- not as the runtime "mongodb" user that gosu
#     switches to for mongod.
#   * The image sets `ENV HOME /data/db` (so mongosh has a writable HOME). This
#     env var applies to the SSH shell too, so root's $HOME becomes /data/db,
#     which is exactly where Render mounts the persistent disk. Render does NOT
#     allow the persistent disk to be mounted at the running user's $HOME, so it
#     accepts the key but immediately closes the session.
#
# Fix (all done as root, the user Render connects as):
#   1. Override HOME back to /root, which is NOT on the persistent disk.
#   2. Give root a real login shell and create ~/.ssh (0700).
#   3. Unlock the root account (Render does not allow it to be locked).
#
# mongod keeps using /data/db as its dbpath (the default CMD argument), which is
# independent of $HOME, so the database is unaffected. mongod does not require a
# writable HOME; only the interactive mongosh client does, and that still works
# over the shell since root can write to /root.
USER root

ENV HOME=/root

RUN usermod -s /bin/bash root \
    && usermod -p '*' root \
    && mkdir -p /root/.ssh \
    && chmod 0700 /root/.ssh
