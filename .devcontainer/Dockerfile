# Official repo is https://git.savannah.gnu.org/git/bash.git
ARG JB_BASH_GIT_URL=https://github.com/bminor/bash.git
ARG BATS_GIT_REV=v1.9.0
# Our tesh examples depend on several bug fix PRs I made which are yet to be merged
ARG TESH_SOURCE=git+https://github.com/h4l/tesh.git@h4ls-patches


FROM mcr.microsoft.com/devcontainers/base:bullseye AS base


FROM base AS bash-git-repo
ARG JB_BASH_GIT_URL
RUN git clone "${JB_BASH_GIT_URL:?}" /bash-git
WORKDIR /bash-git
RUN apt-get update && apt-get install -y autoconf


# The bash git repo is a bit different to a normal repo. It doesn't have tags
# patch version releases, rather each commit is basically a patch version.
FROM bash-git-repo AS bash-4.4.19
RUN git checkout b0776d8c49ab4310fa056ce1033985996c5b9807 \
  && ./configure --prefix=/opt/bash-4.4.19 && make -j4 && make -j4 install
FROM bash-git-repo AS bash-5.0.18
RUN git checkout 36f2c406ff27995392a9247dfa90672fdaf7dc43 \
  && ./configure --prefix=/opt/bash-5.0.18 && make -j4 && make -j4 install
FROM bash-git-repo AS bash-5.1.16
RUN git checkout 9439ce094c9aa7557a9d53ac7b412a23aa66e36b \
  && ./configure --prefix=/opt/bash-5.1.16 && make -j4 && make -j4 install
FROM bash-git-repo AS bash-5.2.15
RUN git checkout ec8113b9861375e4e17b3307372569d429dec814 \
  && ./configure --prefix=/opt/bash-5.2.15 && make -j4 && make -j4 install


FROM base AS bats
ARG BATS_GIT_REV
WORKDIR /bats
RUN git clone --depth=1 --single-branch --branch="${BATS_GIT_REV:?}" \
  https://github.com/bats-core/bats-core.git


FROM base
ARG TESH_SOURCE
RUN apt-get update \
  && apt-get install -y python3-pip python3-venv \
  && pip3 install pipx \
  && pipx install "${TESH_SOURCE:?}"

COPY --from=bats /bats /opt/bats
ENV PATH=/opt/bats/bats-core/bin:$PATH

COPY --from=bash-4.4.19 /opt/bash-4.4.19 /opt/bash-4.4.19
COPY --from=bash-5.0.18 /opt/bash-5.0.18 /opt/bash-5.0.18
COPY --from=bash-5.1.16 /opt/bash-5.1.16 /opt/bash-5.1.16
COPY --from=bash-5.2.15 /opt/bash-5.2.15 /opt/bash-5.2.15
ENV PATH="/opt/bash-5.2.15/bin:/opt/bash-5.1.16/bin:/opt/bash-5.0.18/bin:/opt/bash-4.4.19/bin:$PATH"
