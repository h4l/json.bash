TESH_SOURCE = "tesh>=0.3.0,<0.4"
# Official repo is https://git.savannah.gnu.org/git/bash.git
JB_BASH_GIT_URL = "https://github.com/bminor/bash.git"
TAG_BASE = "ghcr.io/h4l/json.bash"
NOW = "${timestamp()}"

variable CI {
  default = "false"
}
_DEFAULT_JSON_BASH_VERSION = "0.2.2-dev"
variable JSON_BASH_VERSION {
  default = ""
}

BASH_VERSIONS = ["4.4.19", "5.0.18", "5.1.16", "5.2.15"]

target "base" {
  args = {
    BAKE_LOCAL_PLATFORM = BAKE_LOCAL_PLATFORM
    TAG_BASE = TAG_BASE
  }
  platforms = CI == "true" ? ["linux/amd64", "linux/arm64"] : [BAKE_LOCAL_PLATFORM]
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
    bats-core-git = "https://github.com/bats-core/bats-core.git"
  }
  args = {
    TEST_OS = os
    TESH_SOURCE = TESH_SOURCE
  }
  target = "ci"
  labels = {
    "com.github.h4l.json-bash.os" = os
    "com.github.h4l.json-bash.bash-version" = bash.ver
  }
  tags = ["${TAG_BASE}/ci:${os}-bash_${bash.ver}"]
}

target "tests_base" {
  inherits = ["base"]
  platforms = [BAKE_LOCAL_PLATFORM]
}

TEST_MATRIX = { bash = BASH_VERSIONS, os = ["debian", "alpine"] }

target "bats" {
  matrix = TEST_MATRIX

  name = "bats-${os}-bash_${replace(bash, ".", "-")}"
  inherits = ["tests_base"]
  args = {
    TEST_ENV_TAG = "${os}-bash_${bash}"
    CI = CI
  }
  contexts = { repo = "." }
  no-cache-filter = ["run-bats"]  # always re-run tests
  target = "result-bats"
  output = ["type=local,dest=build/${NOW}/bats-${os}-bash_${bash}/"]
}

target "tesh" {
  matrix = TEST_MATRIX

  name = "tesh-${os}-bash_${replace(bash, ".", "-")}"
  inherits = ["tests_base"]
  args = {
    TEST_ENV_TAG = "${os}-bash_${bash}"
  }
  contexts = { repo = "." }
  no-cache-filter = ["run-tesh"]  # always re-run tests
  target = "result-tesh"
  output = ["type=local,dest=build/${NOW}/tesh-debian-bash_${bash}/"]
}

function "json_bash_version" {
  params = []
  result = JSON_BASH_VERSION == "" ? _DEFAULT_JSON_BASH_VERSION : JSON_BASH_VERSION
}

function "parse_version" {
  params = []
  result = regex("^(\\d+)\\.(\\d+)\\.(\\d+)$", json_bash_version())
}

function "image_tags" {
  params = []
  result = try(
    // release version
    [
      "latest",
      "${parse_version()[0]}",
      "${parse_version()[0]}.${parse_version()[1]}",
      "${parse_version()[0]}.${parse_version()[1]}.${parse_version()[2]}",
    ],
    // non-release version
    [json_bash_version()]
  )
}

target "end_user_base" {
  inherits = ["base"]
  args = {
    JSON_BASH_VERSION = json_bash_version()
  }
}

// The pkg image can generate json.bash package-manager packages in various formats
target "pkg" {
  inherits = ["end_user_base"]
  target = "pkg"
  tags = formatlist("${TAG_BASE}/pkg:%s", image_tags())
  contexts = { repo = "." }
}

// The jb image contains json.bash & the jb-* programs
target "jb" {
  inherits = ["end_user_base"]
  target = "jb"
  tags = formatlist("${TAG_BASE}/jb:%s", image_tags())
  contexts = { repo = "." }
}
