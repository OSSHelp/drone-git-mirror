# git-mirror

[![Build Status](https://drone.osshelp.ru/api/badges/drone/drone-git-mirror/status.svg)](https://drone.osshelp.ru/drone/drone-git-mirror)

## About

The image is used for mirroring our repos to external ones.

## Usage example

### Partial mirror (rsync)

Performs if `mirror_ignore_list` file exists.

``` yaml
steps:
  - name: mirror
    image: osshelp/drone-git-mirror
    settings:
      target_repo: git@github.com:OSSHelp/some-repo.git
      ssh_key:
        from_secret: git-mirror-private-key
```

### Full mirror

Performs if `mirror_ignore_list` file doesn't exists and the clone step is disabled.

``` yaml
trigger:
  event: [push, tag]

clone:
  disable: true

steps:
  - name: mirror
    image: osshelp/drone-git-mirror
    settings:
      target_repo: git@github.com:OSSHelp/some-repo.git
      ssh_key:
        from_secret: git-mirror-private-key
```

## Params

| Param | Default | Description |
| -------- | -------- | -------- |
| `target_repo` | - | SSH clone URL of target repo |
| `ssh_key` | - | Private key with R/W permissions to use for interacting with `target_repo`. |
| `git_email` | `drone@osshelp` | E-mail that will be used while pushing changes |
| `git_name` | `Drone CI` | Name that will be used while pushing changes |
| `ignore_errors` | `false` | If set to `true` the plugin will try to ignore all occurring errors to prevent build failing because of itself. **This setting must be used with project-manager approval only and only for a limited time (not a long-term solution)** |
| `mirror_ignore_list` | `.mirror_ignore` | If this file is found in repo root - it contents will be used as excludement list for mirroring |

### Internal usage

For internal purposes and OSSHelp customers we have an alternative image url:

``` yaml
  image: oss.help/drone/git-mirror
```

There is no difference between the DockerHub image and the oss.help/drone image.

## FAQ

### How to exclude unwanted files from sync

By default plugin will try to mirror repository contents to `target_repo` "as is". If you want to exclude some files from mirroring you need to create a file, named `.mirror_ignore` (if not overwritten with `mirror_ignore_list` variable) in repo root. Describe wanted and unwanted files and directories inside as if you are preparing a file for using with `--exclude-from` rsync flag (GNU tar way). For example:

``` plaintext
.drone.yml
.mirror_ignore
file1.txt
dir1/*
dir2
```

### How to delete excluded files or trash branches from remote repo

Files, excluded with `mirror_ignore_list` will not be automatically removed from remote repo. Neither do branches. No plans of implementing such functionality.

## TODO

- hide private key in debug output
- add the way to override the target branch in remote repo (master pinned for now)
- deal with tags not being mirrored in "partial" scenario
