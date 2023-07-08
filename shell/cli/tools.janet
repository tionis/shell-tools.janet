#!/bin/env janet
(use ../cli)
(import ../entr)
(import ../init :as shell)
(description "shell tools")

(defc entr/this
  "simply watch working dir and execute args on change"
  [& args]
  (entr/inotify
    ["."]
    (fn []
        (def code (os/execute args :p))
        (shell/pp [:exit-code code]))))

(defc entr
  "simple entr replacement"
  {:options {"dir" {:kind :accumulate
                    :help "dir to watch"}
             :default {:kind :accumulate}}
   :cli/func |(($0 :func) ($0 "dir") ($0 :default))}
  [dirs args]
  (entr/inotify
    ["."]
    (fn []
        (def code (os/execute args :p))
        (shell/pp [:exit-code code]))))

(defc entr/dirs
  "watch dirs and execute args on change"
  {:cli/func split-at-double-dash
   :cli/doc "take all args until -- as dirs to watch, use rest as args for command to execute on change"}
  [dirs args]
  (entr/inotify
    ["."]
    (fn []
        (def code (os/execute args :p))
        (shell/pp [:exit-code code]))))
