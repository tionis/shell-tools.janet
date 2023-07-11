#!/bin/env janet
(import spork/argparse :prefix "")
(use ../git/interactive-sparse-clone)

(def argparse-params
  [`Clone repo and sparse check it out interactively`
   "ref" {:kind :option
          :short "r"
          :default "origin/main"
          :help "Ref to check out"}
   :default {:kind :accumulate
             :help "remote to clone and optionally a path to clone it to"}])

(defn main [_ remote & args]
  (def res (argparse ;argparse-params))
  (unless res (os/exit 1))

  (interactive-sparse-clone (first (res :default))
                            :ref (res "ref")
                            :path (get (res :default) 1 nil)))
