#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Exercises bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario creates a repository in a temporary directory, gives it role
# files and a release history, and then replays a series of merges through the
# real script, tagging as it goes just like the autotag workflow does. This
# repository is never touched and no network access is needed.

set -euo pipefail

script_under_test="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

failures=0
workdir=''

cleanup() {
	cd /
	if [ -n "$workdir" ]; then
		rm -rf "$workdir"
		workdir=''
	fi
}

trap cleanup EXIT

# The defaults fixture mirrors the shape of the real defaults/main.yml: the
# Renovate annotation sits directly above the version, and the container image
# variables below it derive from the version through Jinja. Only the literal
# `crowdsec_version` value may be picked up - a script keying on the derived
# variables would read `{{ crowdsec_version }}` and produce nonsense tags.
write_defaults() {
	cat > defaults/main.yml <<-EOF
		# renovate: datasource=docker depName=crowdsecurity/crowdsec versioning=semver
		crowdsec_version: $1

		crowdsec_container_image: "{{ crowdsec_container_image_registry_prefix }}crowdsecurity/crowdsec:{{ crowdsec_container_image_tag }}"
		crowdsec_container_image_tag: "{{ crowdsec_version }}-debian"
	EOF
}

# Starts a scenario with a repository at CrowdSec v1.8.2 which has already
# seen two releases of it (v1.8.2-0 and v1.8.2-1).
scenario() {
	echo "$1"

	cleanup
	workdir="$(mktemp -d)"

	mkdir -p "$workdir/bin" "$workdir/defaults" "$workdir/tasks" "$workdir/templates"
	cp "$script_under_test" "$workdir/bin/"
	cd "$workdir"

	git init -q -b main .
	git config user.email 'test@example.com'
	git config user.name 'Test'
	git config commit.gpgsign false

	write_defaults v1.8.2
	printf 'placeholder\n' > tasks/main.yml
	printf 'placeholder\n' > templates/env.j2
	printf 'placeholder\n' > README.md

	git add -A
	git commit -qm 'Initial commit'

	local release_number
	for release_number in 0 1; do
		git tag "v1.8.2-$release_number"
	done
}

# Applies a change, commits it, and tags whatever the script says it should be.
# Prints the tag, or nothing when the script decided against a release.
merge() {
	local change="$1" tag

	eval "$change"
	git add -A
	git commit -qm 'Merge'

	tag="$(bin/compute-next-tag.sh 2>/dev/null)"

	if [ -n "$tag" ]; then
		git tag "$tag"
	fi

	printf '%s' "$tag"
}

expect() {
	local description="$1" expected="$2" actual="$3"

	if [ "$actual" = "$expected" ]; then
		printf '  ok   | %s -> %s\n' "$description" "${actual:-no release}"
	else
		printf '  FAIL | %s -> expected %s, got %s\n' "$description" "${expected:-no release}" "${actual:-no release}"
		failures=$((failures + 1))
	fi
}

bump_version='write_defaults v1.8.3'
revert_version='write_defaults v1.8.2'
unprefixed_version='write_defaults 1.8.3'
edit_task="printf 'a task\n' >> tasks/main.yml"
edit_template="printf 'a line\n' >> templates/env.j2"
edit_readme="printf 'documentation\n' >> README.md"
edit_script="printf '# a comment\n' >> bin/compute-next-tag.sh"

# The two merge orders below apply the same updates and must each end up with
# every update released exactly once, whichever order they arrive in.

scenario 'A version bump merged before other role changes'
expect 'version bump' v1.8.3-0 "$(merge "$bump_version")"
expect 'task edit'    v1.8.3-1 "$(merge "$edit_task")"
expect 'template'     v1.8.3-2 "$(merge "$edit_template")"

scenario 'A version bump merged after other role changes'
expect 'task edit'    v1.8.2-2 "$(merge "$edit_task")"
expect 'version bump' v1.8.3-0 "$(merge "$bump_version")"

scenario 'Commits that do not affect the role'
expect 'README'   ''         "$(merge "$edit_readme")"
expect 'a script' ''         "$(merge "$edit_script")"
expect 'a task'   v1.8.2-2 "$(merge "$edit_task")"

scenario 'Release numbers past 9'
for release_number in 2 3 4 5 6 7 8 9 10; do
	git tag "v1.8.2-$release_number"
done
expect 'a task' v1.8.2-11 "$(merge "$edit_task")"

scenario 'Reverting to an already released version'
merge "$bump_version" > /dev/null
# The role is now identical to what v1.8.2-1 already published, so there is
# nothing new to release.
expect 'a revert' '' "$(merge "$revert_version")"

scenario 'Reverting to an already released version, with a change'
merge "$bump_version" > /dev/null
expect 'a revert' v1.8.2-2 "$(merge "$revert_version && $edit_task")"

# The version variable is quoted in some roles and bare in others, and the
# derived image variables must never be mistaken for it.
scenario 'A quoted version value with its leading v'
expect 'quoted bump' v1.8.3-0 "$(merge 'printf "%s\n" "# renovate: datasource=docker depName=crowdsecurity/crowdsec versioning=semver" "crowdsec_version: \"v1.8.3\"" "crowdsec_container_image_tag: \"{{ crowdsec_version }}-debian\"" > defaults/main.yml')"

scenario 'A version value without a leading v still gets one in the tag'
expect 'unprefixed bump' v1.8.3-0 "$(merge "$unprefixed_version")"

if [ "$failures" -gt 0 ]; then
	echo >&2 "$failures scenario(s) behaved unexpectedly"
	exit 1
fi

echo 'All scenarios behaved as expected'
