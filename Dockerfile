FROM mongo:8.0

# Enable Render SSH / Shell access for this Docker image.
# See: https://render.com/docs/ssh#docker-specific-configuration
#
# The official mongo image runs as the "root" user by default, so we configure
# SSH access for root:
#   1. Render does not allow the root account to be locked, so unlock it.
#   2. Ensure root has shell access.
#   3. Create the ~/.ssh directory with the correct permissions (0700).
#
# Note: the mongo image does not run its own SSH server (nothing listens on
# port 22), and the persistent disk is mounted at /data/db (not root's $HOME),
# both of which are required by Render.
USER root

RUN (usermod --unlock root || passwd -u root || true) \
    && usermod -s /bin/bash root \
    && mkdir -p /root/.ssh \
    && chmod 0700 /root/.ssh
