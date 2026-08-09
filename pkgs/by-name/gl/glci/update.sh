#!/usr/bin/env nix-shell
#!nix-shell -i bash -p common-updater-scripts curl jq nix-update

set -euo pipefail

latest=$(
  curl --fail --location --silent --show-error \
    "https://gitlab.com/api/v4/projects/gitlab-org%2Fci-cd%2Frunner-tools%2Fglci/repository/tags?per_page=100" \
    | jq --exit-status '
      map(select(
        (.name | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))
        and (.commit.id | test("^[0-9a-f]{40}$"))
      ))
      | max_by(.name | ltrimstr("v") | split(".") | map(tonumber))
    '
)

version=$(jq --raw-output '.name | ltrimstr("v")' <<< "$latest")
rev=$(jq --raw-output '.commit.id' <<< "$latest")

update-source-version glci "$version" --rev="$rev"
nix-update glci --version=skip
