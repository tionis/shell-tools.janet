#!/bin/bash
die(){
  echo "$1" >&2
  if test -z "$2"; then
    exit 1
  else
    exit "$2"
  fi
}

verify-one-commit(){
  # Verify a commit using the allowed_signers from it's parent
  commit="$1"
  dir=$(mktemp -d) # create a tempdir

  # load parents allowed_signers
  git show "${commit}^:$allowed_signers_relative_path" > "$dir/allowed_signers"

  # extract signature from commit object
  out="$dir/commit.raw"
  git cat-file -p "$commit" | while read -r line; do
    if (echo "$line" | grep '^gpgsig -----BEGIN SSH SIGNATURE-----$' >/dev/null); then
      out="$dir/commit.sig"
      echo "$line" | grep -oP '(?<=gpgsig ).*$' >> "$out"
    elif (echo "$line" | grep '^-----END SSH SIGNATURE-----$' >/dev/null); then
      echo "$line" >> "$out"
      out="$dir/commit.raw"
    else
      echo "$line" >> "$out"
    fi
  done || return 1
  if ! test -f "$dir/commit.sig"; then
    echo "Could not detect signature for commit $commit"
    return 1
  fi
  # finally verify commit
  ssh-keygen \
    -Y verify \
    -f "$dir/allowed_signers" \
    -n git \
    -s "$dir/commit.sig" \
    -I "$(ssh-keygen -Y find-principals -s "$dir/commit.sig" -f "$dir/allowed_signers")" < "$dir/commit.raw" || return 1
}

check-allowed-signers(){
  # Abort if there is no allowed_signers to check against
  allowed_signers_absolute_path=$(git config --local skm.allowedSignersFile)
  if test -z "$allowed_signers_absolute_path"; then
    git config --local skm.allowedSignersFile "$(pwd)/.allowed_signers"
    allowed_signers_absolute_path=$(git config --local skm.allowedSignersFile)
  fi
  repo_root=$(git rev-parse --show-toplevel)
  allowed_signers_relative_path=${allowed_signers_absolute_path##"$repo_root/"}
  # TODO ensure relative path is available in whole script
  if test "$allowed_signers_relative_path" = "$allowed_signers_absolute_path"; then
    # allowed_signers is outside of current git repo
    dont_verify_allowed_signers=true # TODO integrate this var with rest
  fi
  if ! test -f "$allowed_signers_absolute_path"; then
    die "No allowed_signers found!"
  fi
}

ensure-allowed-signers-trusted(){
  check-allowed-signers
  if test "$dont_verify_allowed_signers" = "true"; then
    return
  fi
  # Get last_verified_commit as trust anchor
  last_verified_commit="$(git config skm.last-verified-commit)"
  if test -z "$last_verified_commit"; then
    die "No last verified commit set, please set it as the root of trust using 'git config skm.last-verified-commit \$COMMIT_HASH' or 'git skm trust \$COMMIT_HASH'"
  fi

  # Build array of commits to verify
  all_commits="$(git log --pretty=format:%H "$allowed_signers_relative_path")"
  commits_to_verify=()
  for commit in $all_commits; do
    if ! test "$commit" = "$last_verified_commit"; then
      commits_to_verify+=("$commit")
    else
      found_commit="true"
      break
    fi
  done
  if ! test "$found_commit" = "true"; then
    die "Could not find last_verified_commit, please ensure it exists in the current history"
  fi

  # Verify all commits in reverse iterativly
  min=0
  max=$(( ${#commits_to_verify[@]} -1 ))
  while test $min -le $max; do
    commit="${commits_to_verify[$max]}"
    verify-one-commit "$commit" || die "Could not verify commit $commit"
    last_verified_commit="$commit"
    ((max=max-1))
  done
  git config skm.last-verified-commit "$last_verified_commit"
  allowed_signers_cache_file_path="$(realpath "$(git rev-parse --git-dir)")/allowed_signers"
  cp "$allowed_signers_absolute_path" "$allowed_signers_cache_file_path"
  git config gpg.ssh.allowedSignersFile "$allowed_signers_absolute_path"
  echo "allowed_signers was verified and copied into git_dir"
}

print-help(){
  echo "simple git signatures"
  echo "available subcommands:"
  echo "  help - show this help"
  echo "  generate - generate the allowed_signers file and do nothing else"
  echo "  verify-commit - verify a specific commit (or HEAD if no commit ref was given)"
  echo "  trust - set trust anchor (this is the last commit hash that you trust)"
}

case "$1" in
  help|--help|-h|h)
    print-help
    ;;
  verify-commit)
    ensure-allowed-signers-trusted
    git verify-commit "${2:-HEAD}" || exit 1
    ;;
  generate)
    ensure-allowed-signers-trusted
    ;;
  trust)
    if test -z "$2"; then
      git config skm.last-verified-commit
    else
      git config skm.last-verified-commit "$2"
    fi
    ;;
  encrypt|decrypt|verify|gen-keys)
    die "not implemented yet"
    ;;
  *)
    print-help
    ;;
esac
