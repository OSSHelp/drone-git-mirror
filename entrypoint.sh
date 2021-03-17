#!/bin/bash
# shellcheck disable=SC2015

[ "${PLUGIN_DEBUG}" = "true" ] && { set -x; env; }

function prepare_vars() {
    build_failed=1
    git_email='drone@osshelp.ru'
    git_name='Drone CI'
    mirror_mode=full
    ignore_errors=false
    tmp_dir=/tmp/remote
    current_repo_dir=/drone/src
    mirror_ignore_list="${current_repo_dir}/.mirror_ignore"

    test -n "${PLUGIN_TARGET_REPO}"        && target_repo="${PLUGIN_TARGET_REPO}"
    test -n "${PLUGIN_GIT_NAME}"           && git_name="${PLUGIN_GIT_NAME}"
    test -n "${PLUGIN_GIT_EMAIL}"          && git_email="${PLUGIN_GIT_EMAIL}"
    test -n "${PLUGIN_IGNORE_ERRORS}"      && ignore_errors="${PLUGIN_IGNORE_ERRORS}"
    test -n "${CI_WORKSPACE}"              && current_repo_dir="${CI_WORKSPACE}"
    test -n "${PLUGIN_MIRROR_IGNORE_LIST}" && mirror_ignore_list="${current_repo_dir}/${PLUGIN_MIRROR_IGNORE_LIST}"

    test "${target_repo:-none}" == "none" && \
      show_error "No target repo specified"
    test -f "${mirror_ignore_list}" -a -s "${mirror_ignore_list}" && \
      mirror_mode=partial
    test -z "${PLUGIN_SSH_KEY}" -a -z "${PLUGIN_SSH_KEY_FILE}" && \
      show_error "No private key specified"
    test -n "${PLUGIN_SSH_KEY_FILE}" -a ! -r "${PLUGIN_SSH_KEY_FILE}" && \
      show_error "Can't read private key from ${PLUGIN_SSH_KEY_FILE}"
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
  test "${mirror_mode}" == "full" && {
    show_notice "Preparing ~/.netrc file"
    echo "machine $DRONE_NETRC_MACHINE" > ~/.netrc
    echo "login $DRONE_NETRC_USERNAME" >> ~/.netrc
    echo "password $DRONE_NETRC_PASSWORD" >> ~/.netrc
    chmod 600 ~/.netrc
  }

  show_notice "Preparing private key and known_hosts"
  local key_file=~/.ssh/id_rsa
  mkdir -p ~/.ssh
  chmod -R go-rwx ~/.ssh
  test -n "${PLUGIN_SSH_KEY}" && echo "${PLUGIN_SSH_KEY}" > "${key_file}"
  test -z "${PLUGIN_SSH_KEY}" && cat "${PLUGIN_SSH_KEY_FILE}" > "${key_file}"
  chown root:root "${key_file}" && \
    chmod 0600 "${key_file}"
  ssh-keyscan -t rsa,dsa,ecdsa "$(sed -r 's/.+@//;s/:.+//' <<< "${target_repo}")" >> ~/.ssh/known_hosts
}

function clone_target_repo() {
  local err=1
  show_notice "Cloning repository from ${target_repo} to ${tmp_dir}"
  test -d "${tmp_dir}" || mkdir -p "${tmp_dir}"
  git clone "${target_repo}" "${tmp_dir}" && err=0
  return "${err}"
}

function sync_changes_from_current_repo() {
  show_notice "Syncing chages from ${current_repo_dir} to ${tmp_dir}"
  local err=1
  rsync -icrv --delete --exclude '.git' --exclude-from="${mirror_ignore_list}" "${current_repo_dir}/" "${tmp_dir}/" && \
    err=0
  return "${err}"
}

function prepare_bare_repo() {
  local err=1
  show_notice "Prepare a bare repository from ${DRONE_REMOTE_URL}"
  git init --bare . \
  && git config remote.origin.url "${DRONE_REMOTE_URL}" \
  && git config --add remote.origin.fetch '+refs/heads/*:refs/heads/*' \
  && git config --add remote.origin.fetch '+refs/tags/*:refs/tags/*' \
  && git config remote.origin.mirror true \
  && git fetch --all \
  && err=0
  return "${err}"
}

function push_changes_to_remote_repo() {
  local err=1

  show_notice "Commit will be made as \"${git_name}\" with ${git_email} as an email"

  git config --global user.email "${git_email}"
  git config --global user.name "${git_name}"

  test "${mirror_mode}" == "full" && {
    test ! -d .git || show_error "You have to disable clone step for perform full mirroring. See the plugin docs"
    prepare_bare_repo \
    && git remote add neworigin "${target_repo}" \
    && show_notice "Performing full mirroring to ${target_repo}" \
    && git push neworigin --mirror \
    && err=0
  }

  test "${mirror_mode}" == "partial" && {
    show_notice "Performing partial mirroring"
    clone_target_repo && \
      sync_changes_from_current_repo && {
        cd "${tmp_dir}" || show_error "Failed to change directory to ${tmp_dir}"
        show_notice "Adding files to the index"
        git add .
        show_notice "Commiting changes"
        git commit -am "${DRONE_COMMIT_MESSAGE}"
        show_notice "Here is the latest commit"
        git log -n 1
        show_notice "Pushing changes to ${target_repo}"
        git push && \
          err=0
      }
  }
  return "${err}"
}

# clearing out the env
for target_var in $(env | grep -E '^GIT_.+=' | cut -f 1 -d '='); do
  unset "${target_var}";
done

# build working env
prepare_vars
prepare_repo_access

# upload
push_changes_to_remote_repo && \
  build_failed=0

# results
test "${build_failed}" != 0 && {
  test "${ignore_errors,,}" == "true" -o "${ignore_errors}" == "1" && {
    echo "Exiting with 0 code, because \"ignore_errors\" param is set to \"${ignore_errors}\""
    exit 0
  }
}

exit "${build_failed}"
