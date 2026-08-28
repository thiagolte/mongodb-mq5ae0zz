FROM mongo:8.0

# SERVER-121912: on Linux kernels 6.19 through 7.0.13 (which is what Render's
# hosts run), mongod refuses to start with:
#
#   {"s":"F","c":"CONTROL","id":12257600,"msg":"MongoDB cannot start: Linux
#    kernel versions 6.19 and newer has a known incompatibility with this
#    version of MongoDB."}
#
# The conflict is in the vendored TCMalloc: by default MongoDB disables glibc's
# own rseq registration (glibc.pthread.rseq=0) so TCMalloc can register rseq
# itself, and that registration violates the rseq ABI enforced by kernel 6.19+.
# mongod detects this unsafe configuration at startup and exits on purpose.
#
# Forcing glibc.pthread.rseq=1 makes TCMalloc use glibc's (ABI-correct) rseq
# registration instead, which is the supported path on these kernels: the
# startup check then passes and mongod runs normally. This affects only the
# memory allocator's per-CPU fast path -- no data or configuration impact.
#
# Remove this line once Render moves to kernel 7.0.14 or later, where MongoDB
# no longer needs the workaround.
ENV GLIBC_TUNABLES=glibc.pthread.rseq=1

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
