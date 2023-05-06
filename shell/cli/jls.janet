#!/bin/env janet
# TODO detect symlinks and transform them via $file_name -> $target
(use spork)
(def argparse/params
  ["simple ls implementation in janet"
   "all" {:kind :flag
          :short "a"
          :description "list all"}
   :default {:kind :accumulate}])

(defn ls [path]
  (each file (sort (os/dir path))
    (def file_path (path/join path file))
    (def stat (os/stat file_path))
    (if stat
      (print (if (= (stat :mode) :directory) "d" "-")
             (stat :permissions)
             "  "
             file_path)
      (print file_path " not found"))))

(defn main [_ &]
  (def res (argparse/argparse ;argparse/params))
  (unless res (os/exit 1))
  (def path (first (res :default)))
  (if path (ls path) (ls ".")))
