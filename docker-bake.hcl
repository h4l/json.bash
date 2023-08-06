BATS_GIT_REV = "v1.9.0"
# Our tesh examples depend on several bug fix PRs I made which are yet to be merged
TESH_SOURCE = "git+https://github.com/h4l/tesh.git@h4ls-patches"
# Official repo is https://git.savannah.gnu.org/git/bash.git
JB_BASH_GIT_URL = "https://github.com/bminor/bash.git"
TAG_BASE = "ghcr.io/h4l/json.bash"
NOW = "${timestamp()}"

BASH_VERSIONS = ["4.4.19", "5.0.18", "5.1.16", "5.2.15"]

target "base" {
  args = {
    TAG_BASE = TAG_BASE
    BATS_GIT_REV = BATS_GIT_REV
    TESH_SOURCE = TESH_SOURCE
  }
  contexts = {
    bats-core-git = "https://github.com/bats-core/bats-core.git"
  }
}

target "devcontainer" {
  context = ".devcontainer"
  args = { JB_BASH_GIT_URL = JB_BASH_GIT_URL }
  tags = ["${TAG_BASE}/devcontainer:latest"]
}

// The ci images are pre-built and used when running test matrix
target "ci" {
  matrix = {
    bash = [
      { sha = "b0776d8c49ab4310fa056ce1033985996c5b9807", ver = "4.4.19" },
      { sha = "36f2c406ff27995392a9247dfa90672fdaf7dc43", ver = "5.0.18" },
      { sha = "9439ce094c9aa7557a9d53ac7b412a23aa66e36b", ver = "5.1.16" },
      { sha = "ec8113b9861375e4e17b3307372569d429dec814", ver = "5.2.15" }
    ]
    os = ["alpine", "debian"]
  }

  name = "ci-${os}-bash_${replace(bash.ver, ".", "-")}"
  inherits = ["base"]
  contexts = {
    bash-git = "${JB_BASH_GIT_URL}#${bash.sha}"
  }
  args = { TEST_OS = os }
  target = "ci"
  labels = {
    "com.github.h4l.json-bash.os" = os
    "com.github.h4l.json-bash.bash-version" = bash.ver
  }
  tags = ["${TAG_BASE}/ci:${os}-bash_${bash.ver}"]
}

target "ci-debian" {
  matrix = {
    bash = BASH_VERSIONS
  }

  name = "ci-debian-bash_${replace(bash, ".", "-")}"
}

TEST_MATRIX = { bash = BASH_VERSIONS, os = ["debian", "alpine"] }

target "bats" {
  matrix = TEST_MATRIX

  name = "bats-${os}-bash_${replace(bash, ".", "-")}"
  inherits = ["base"]
  args = {
    TEST_ENV_TAG = "${os}-bash_${bash}"
  }
  contexts = { repo = "." }
  no-cache-filter = ["run-bats"]  # always re-run tests
  target = "result-bats"
  output = ["type=local,dest=build/${NOW}/bats-${os}-bash_${bash}/"]
}

target "tesh" {
  matrix = TEST_MATRIX

  name = "tesh-${os}-bash_${replace(bash, ".", "-")}"
  inherits = ["base"]
  args = {
    TEST_ENV_TAG = "${os}-bash_${bash}"
  }
  contexts = { repo = "." }
  no-cache-filter = ["run-tesh"]  # always re-run tests
  target = "result-tesh"
  output = ["type=local,dest=build/${NOW}/tesh-debian-bash_${bash}/"]
}
