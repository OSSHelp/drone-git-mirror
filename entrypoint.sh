#!/bin/bash
# shellcheck disable=SC2015

[ "${PLUGIN_DEBUG}" = "true" ] && { set -x; env; }

function prepare_vars() {
    build_failed=1
    git_email='drone@osshelp.ru'
    git_name='Drone CI'
    mirror_mode=full
    ignore_errors=false
    tmp_dir=/src/tmp_repo_dir
    current_repo_dir=/drone/src
    mirror_ignore_list="${current_repo_dir}/.mirror_ignore"

    test -n "$PLUGIN_TARGET_REPO"        && target_repo="$PLUGIN_TARGET_REPO"
    test -n "$PLUGIN_GIT_NAME"           && git_name="$PLUGIN_GIT_NAME"
    test -n "$PLUGIN_GIT_EMAIL"          && git_email="$PLUGIN_GIT_EMAIL"
    test -n "$PLUGIN_IGNORE_ERRORS"      && ignore_errors="$PLUGIN_IGNORE_ERRORS"
    test -n "$CI_WORKSPACE"              && current_repo_dir="$CI_WORKSPACE"
    test -n "$PLUGIN_MIRROR_IGNORE_LIST" && mirror_ignore_list="${current_repo_dir}/$PLUGIN_MIRROR_IGNORE_LIST"

    test "${target_repo:-none}" == "none" && \
      show_error "No target repo specified"
    test -f "${mirror_ignore_list}" -a -s "${mirror_ignore_list}" && \
      mirror_mode=partial
    test -z "$PLUGIN_SSH_KEY" && \
      show_error "No private key specified"
}

function show_notice()  { echo -e "\e[34m[NOTICE. $(date '+%Y/%m/%d-%H:%M:%S')]\e[39m ${1}"; }
function show_warning() { echo -e "\e[33m[WARNING. $(date '+%Y/%m/%d-%H:%M:%S')]\e[39m ${1}" >&2; }
function show_error()   {
  echo -e "\e[31m[ERROR. $(date '+%Y/%m/%d-%H:%M:%S')]\e[39m ${1}" >&2
  test "${ignore_errors,,}" == "true" -o "${ignore_errors}" == "1" && {
    echo "Exiting with 0 code, because \"ignore_errors\" param is set to \"${ignore_errors}\""
    exit 0
  }
  exit 1
}

function prepare_repo_access() {
  local key_file=~/.ssh/id_rsa
  mkdir -p ~/.ssh
  chmod -R go-rwx ~/.ssh
  echo "$PLUGIN_SSH_KEY" > "${key_file}"
  chown root:root "${key_file}" && \
    chmod 0600 "${key_file}"
  ssh-keyscan -t rsa,dsa,ecdsa "$(sed -r 's/.+@//;s/:.+//' <<< "${target_repo}")" >> ~/.ssh/known_hosts
}

function clone_target_repo() {
  local err=1
  test -d "${tmp_dir}" || \
    mkdir -p "${tmp_dir}"
  git clone "${target_repo}" "${tmp_dir}" && \
    err=0
  return "${err}"
}

function sync_changes_from_current_repo() {
  local err=1
  rsync -av --delete --exclude '.git' --exclude-from="${mirror_ignore_list}" "${current_repo_dir}/" "${tmp_dir}/" && \
    err=0
  return "${err}"
}

function push_changes_to_remote_repo() {
  local err=1

  git config --global user.email "${git_email}"
  git config --global user.name "${git_name}"

  test "${mirror_mode}" == "full" && {
    git remote add neworigin "${target_repo}" && \
      git push -u neworigin "HEAD:$DRONE_REPO_BRANCH" --tags --force && \
        err=0
  }

  test "${mirror_mode}" == "partial" && {
    clone_target_repo && \
      sync_changes_from_current_repo && {
        cd "${tmp_dir}" || \
          show_error "Failed to change directory to ${tmp_dir}"
        git add .
        git commit -am "$DRONE_COMMIT_MESSAGE"
        git push && {
          cd "${current_repo_dir}" && \
            git push --tags "${target_repo}" && \
              err=0
        }
      }
  }
  return "${err}"
}

prepare_vars
prepare_repo_access

push_changes_to_remote_repo && \
  build_failed=0

test "${build_failed}" != 0 && {
  test "${ignore_errors,,}" == "true" -o "${ignore_errors}" == "1" && {
    echo "Exiting with 0 code, because \"ignore_errors\" param is set to \"${ignore_errors}\""
    exit 0
  }
}

exit "${build_failed}"
