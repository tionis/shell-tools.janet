#!/bin/env janet
(import spork/path)
(import spork/sh)
(import jeff)
(use ../exec)

(defn filter-and-split-paths-into-components [p]
  # Use path/posix as git always returns posix parts, if on windows they can be converted later
  (def parts (path/posix/parts p))
  (def ret (array/new (length parts)))
  (array/push ret (get parts 0 "/"))
  (if (> (length parts) 1)
    (do
      (each part (slice parts 1 -1)
        (array/push ret (path/posix/join (last ret) part)))
      ret)
    [])) # Ignore top level or empty paths

(defn interactive-sparse-checkout
  `Interactivly select paths to sparse checkout in a git repo using a fuzzy file selection ui
  ref optionally defines the reference to use to look up the tree of files and later checkout
  git-repo-path optionally passes the repo directory and is passed to git via the -C option`
  [&named ref git-repo-path]
  (default ref "HEAD")
  (def extra-git-opts @[])
  (when git-repo-path
    (array/push extra-git-opts "-C")
    (array/push extra-git-opts git-repo-path))
  (def selected-paths @[])
  (def available-paths
    (->> (sh/exec-slurp "git" ;extra-git-opts "ls-tree" "--name-only" "-r" "-z" ref)
         (string/split "\0")
         (mapcat filter-and-split-paths-into-components)
         (distinct)))
  # TODO support second ui that allows specifying patterns and shows the matching files in a second window or smth like that
  (exec "git" ;extra-git-opts "sparse-checkout" "set" ;(jeff/choose available-paths :multi true))
  (exec "git" ;extra-git-opts "checkout" ref))
