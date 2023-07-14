BATS_GIT_REV = "v1.9.0"
# Our tesh examples depend on several bug fix PRs I made which are yet to be merged
TESH_SOURCE = "git+https://github.com/h4l/tesh.git@h4ls-patches"
# Official repo is https://git.savannah.gnu.org/git/bash.git
JB_BASH_GIT_URL = "https://github.com/bminor/bash.git"
TAG_BASE = "ghcr.io/h4l/json.bash"

target "devcontainer" {
  context = ".devcontainer"
  args = {
    JB_BASH_GIT_URL = JB_BASH_GIT_URL
    TESH_SOURCE = TESH_SOURCE
    BATS_GIT_REV = BATS_GIT_REV
  }
  tags = ["${TAG_BASE}/devcontainer:latest"]
}
