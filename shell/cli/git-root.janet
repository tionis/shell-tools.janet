#!/bin/env janet
(import spork/sh)
(import spork/path)
(import spork/argparse)

(defn root
  "get git root (top most working tree root)"
  [dir]
  (def superproject (sh/exec-slurp "git" "-C" dir "rev-parse" "--show-superproject-working-tree"))
  (if (not= superproject "") superproject (sh/exec-slurp "git" "-C" dir "rev-parse" "--show-toplevel")))

(defn main [_ & args]
  (def args
    (argparse/argparse
      "get root of top-most working tree"
      "relative" {:kind :flag
                  :short "r"
                  :help "get relative path instead"}
      "dir" {:kind :option
             :short "C"
             :default (os/cwd)
             :help "start lookup from this directory as working dir"}))
  (unless args (os/exit 0))
  (def r (root (args "dir")))
  (if (args "relative")
    (print (path/relpath (args "dir") r))
    (print r)))
