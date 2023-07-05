#!/bin/env janet
(use ../cli)
(import ../entr)
(import ../init :as shell)
(setdyn :description "shell tools")

(defn entr/this
  "simply watch working dir and execute args on change"
  :cli
  [& args]
  (entr/inotify
    ["."]
    (fn []
        (def code (os/execute args :p))
        (shell/pp [:exit-code code]))))

(defn entr/dirs
  "splits input"
  :cli
  {:cli/map cli/split-at-double-dash
   :cli/doc "take all args until -- as dirs to watch, use rest as args for command to execute on change"}
  [dirs args]
  (entr/inotify
    ["."]
    (fn []
        (def code (os/execute args :p))
        (shell/pp [:exit-code code]))))
