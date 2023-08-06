ARG TESH_SOURCE TEST_OS TAG_BASE TEST_ENV_TAG=__not_set__


FROM alpine:latest AS alpine-bash-from-src
RUN apk add autoconf build-base
RUN --mount=from=bash-git,src=/,target=/bash-git,rw cd "/bash-git" \
  && ./configure --without-bash-malloc --prefix=/opt/bash && make -j4 && make -j4 install


FROM debian:bookworm AS debian-bash-from-src
RUN apt-get update && apt-get install -y autoconf build-essential
RUN --mount=from=bash-git,src=/,target=/bash-git,rw cd "/bash-git" \
  && ./configure --prefix=/opt/bash && make -j4 && make -j4 install


FROM debian:bookworm AS ci-debian
SHELL ["bash", "-euo", "pipefail", "-c"]
RUN apt-get update \
  && apt-get install -y git jq pipx
# pipx installs to ~/.local/bin
ENV PATH="/root/.local/bin:$PATH"
ARG TESH_SOURCE
RUN pipx install "${TESH_SOURCE:?}"

COPY --from=debian-bash-from-src /opt/bash /opt/bash
ENV PATH="/opt/bash/bin:$PATH"

COPY --from=bats-core-git / /opt/bats/bats-core
ENV PATH=/jb/bin:/opt/bats/bats-core/bin:$PATH


FROM alpine:latest AS ci-alpine
RUN apk add --no-cache \
  coreutils \
  git \
  grep \
  jq \
  python3 \
  py3-pip \
  util-linux
ARG TESH_SOURCE
RUN pip install "${TESH_SOURCE:?}"
COPY --from=alpine-bash-from-src /opt/bash /opt/bash
ENV PATH="/opt/bash/bin:$PATH"
SHELL ["bash", "-euo", "pipefail", "-c"]
COPY --from=bats-core-git / /opt/bats/bats-core
ENV PATH=/jb/bin:/opt/bats/bats-core/bin:$PATH


FROM ci-${TEST_OS:-unused} AS ci


FROM ${TAG_BASE:?}/ci:${TEST_ENV_TAG} AS run-bats
WORKDIR /workspace/repo
RUN mkdir -p /workspace/build
ENV PATH="/workspace/repo/bin:$PATH"
RUN --mount=from=repo,source=/,target=/workspace/repo { \
    { bash --version; \
      bats --print-output-on-failure --formatter tap13 json.bats utilities.bats; \
    } |& tee /workspace/build/bats.log; } || touch /workspace/build/FAIL


FROM ${TAG_BASE:?}/ci:${TEST_ENV_TAG} AS run-tesh
WORKDIR /workspace/repo
RUN mkdir -p /workspace/build
ENV PATH="/workspace/repo/bin:$PATH"
RUN --mount=from=repo,source=/,target=/workspace/repo { \
    tesh README.md docs/stream-poisoning.md \
    |& tee /workspace/build/tesh.log; \
  } || touch /workspace/build/FAIL


FROM scratch AS result-bats
COPY --from=run-bats /workspace/build .

FROM scratch AS result-tesh
COPY --from=run-tesh /workspace/build .
