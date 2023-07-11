#!/bin/env janet
#(import spork/path)
#(import spork/sh)
(import ./remote)
(use ./interactive-sparse-checkout)
(use ../exec)

(defn interactive-sparse-clone [remote &named path ref]
  (default path (remote/get-name remote))
  (default ref "origin/main")

  (os/mkdir path)
  (exec "git" "-C" path "init")
  (exec "git" "-C" path "remote" "add" "origin" remote)
  (exec "git" "-C" path "fetch" "--depth" "1" "origin" "HEAD")
  (exec "git" "-C" path "fetch")
  (interactive-sparse-checkout :git-repo-path path :ref ref))
