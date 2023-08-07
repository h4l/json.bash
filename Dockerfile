# syntax=docker/dockerfile:1.6
ARG TESH_SOURCE TEST_OS TAG_BASE TEST_ENV_TAG=__not_set__ CI BAKE_LOCAL_PLATFORM


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
ARG CI=false
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


# fpm creates all sorts of package-manager packages https://fpm.readthedocs.io/
FROM ruby:3 AS fpm
RUN gem install fpm


FROM fpm as pkg-setup
SHELL ["bash", "-euo", "pipefail", "-c"]
WORKDIR /pkg-src
COPY --from=repo --chmod=755 --chown=root \
  json.bash bin/jb-cat bin/jb-echo bin/jb-stream bin/
RUN cd bin && for prog in jb jb-array; do ln -s json.bash "${prog:?}"; done
ARG JSON_BASH_VERSION
RUN --mount=from=repo,target=/repo <<EOF
JSON_BASH_SOURCE_VERSION=$(. bin/json.bash; echo "${JSON_BASH_VERSION:?}")

# If we're releasing then require that the src and build versions match
if [[ ${JSON_BASH_VERSION:?} =~ [0-9]+\.[0-9]+\.[0-9] ]]; then
  if [[ ${JSON_BASH_VERSION} != ${JSON_BASH_SOURCE_VERSION:?} ]]; then
    echo "Error build version does not match source version: ${JSON_BASH_VERSION@A} ${JSON_BASH_SOURCE_VERSION@Q}" >&2
    exit 1
  fi
fi

SOURCE_DATE_EPOCH_DEFAULT=$(git -C /repo show -s --format=%at HEAD)

echo -n "\
--input-type dir
--name json.bash
--license MIT
--version '${JSON_BASH_VERSION:?}'
--architecture all
--depends bash
--description 'Command-line tool and bash library that creates JSON'
--url 'https://github.com/h4l/json.bash'
--maintainer 'Hal Blackburn'
--source-date-epoch-default '${SOURCE_DATE_EPOCH_DEFAULT:?}'

bin/json.bash=/usr/bin/json.bash
bin/jb=/usr/bin/jb
bin/jb-array=/usr/bin/jb-array
bin/jb-cat=/usr/bin/jb-cat
bin/jb-echo=/usr/bin/jb-echo
bin/jb-stream=/usr/bin/jb-stream
" > .fpm
EOF

FROM fpm AS pkg
ARG JSON_BASH_VERSION
ENV JSON_BASH_VERSION="${JSON_BASH_VERSION:?}"

LABEL org.opencontainers.image.url="https://github.com/h4l/json.bash" \
  org.opencontainers.image.version="${JSON_BASH_VERSION:?}" \
  org.opencontainers.image.licenses="MIT" \
  org.opencontainers.image.title="json.bash package builder" \
  org.opencontainers.image.description="Build package-manager packages for json.bash using FPM"

WORKDIR /pkg
COPY --from=pkg-setup /pkg-src /pkg-src
COPY --chmod=755 <<"EOF" /docker-entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" == 0 || " $* " == *" --help "* ]]; then
  echo "\
Generate json.bash packages for common package managers.

Examples:
  # generate .deb and .rpm package files in the working directory
  $ docker run -v $(pwd):/pkg ghcr.io/h4l/json.bash/pkg deb rpm

  # Get a bash shell instead of generating packages
  $ docker run -it ghcr.io/h4l/json.bash/pkg bash

Usage:
  ghcr.io/h4l/json.bash/pkg <package-type>...
  ghcr.io/h4l/json.bash/pkg [--help]

Info:
  Package sources are in /pkg-src. To generate a package manually:
    $ cd /pkg-src
    $ fpm --output-type deb --package /pkg/json.bash.deb
"
  exit
fi
if [[ "${1:-}" == "bash" ]]; then
  exec bash
fi

out_dir=$(pwd)
cd /pkg-src
log_file=$(mktemp)
for type in "$@"; do
  pkg_filename="${out_dir:?}/json.bash_${JSON_BASH_VERSION:?}.${type:?}"
  if [[ -f "${pkg_filename:?}" ]]; then
    echo "Skipping existing: ${pkg_filename:?}"
    continue;
  fi
  echo "Generating: ${pkg_filename:?}"
  fpm_args=(fpm --output-type "${type:?}" --package "${pkg_filename:?}")
  if ! { "${fpm_args[@]:?}" > "${log_file:?}" 2>&1; }; then
    echo "Failed to generate package by executing: ${fpm_args[@]@Q}" >&2
    cat "${log_file:?}" >&2
  fi
done
EOF
ENTRYPOINT ["/docker-entrypoint.sh"]


FROM --platform=${BAKE_LOCAL_PLATFORM:?} pkg AS pkg-alpine
RUN /docker-entrypoint.sh apk


FROM bash:latest AS jb
ARG JSON_BASH_VERSION

LABEL org.opencontainers.image.url="https://github.com/h4l/json.bash" \
  orgopencontainers.image.version="${JSON_BASH_VERSION:?}" \
  orgopencontainers.image.licenses="MIT" \
  orgopencontainers.image.title="json.bash" \
  org.opencontainers.image.description="Command-line tool and bash library that creates JSON"

RUN --mount=from=pkg-alpine,source=/pkg,target=/pkg \
  apk add --allow-untrusted /pkg/json.bash_*.apk
ENTRYPOINT ["/usr/bin/jb"]
