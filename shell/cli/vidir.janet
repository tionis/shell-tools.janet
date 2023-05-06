#!/bin/env janet
(import spork/sh)
# WARNING: this does not handle newlines and tab characters in filenames
# other problems may also occurr as this is not tested

(defn vidir [path]
  (def old @[])
  (def vidir_file_path (string (os/getenv "HOME") "/.cache/vidir"))
  (each file (os/dir path)
    (def file-stat (os/stat file))
    (if (and file-stat (= (file-stat :mode) :directory))
      (array/push old (string file "/"))
      (array/push old file)))
  (if (not (= nil (os/stat vidir_file_path))) (sh/rm vidir_file_path))
  (def vidir_file (file/open vidir_file_path :wn))
  (loop [i :range [0 (length old)]] (file/write vidir_file (string i "\t" (old i) "\n")))
  (file/close vidir_file)
  (os/execute [(os/getenv "EDITOR") vidir_file_path] :p)
  (def vidir_file (file/open vidir_file_path :rn))
  
  (def new @[])
  (each line (string/split "\n" (string/trim (file/read vidir_file :all)))
    (array/push new (string/split "\t" line)))
  (file/close vidir_file)

  (def new-hash @{})
  # TODO do not loop two times do everything in one loop over old and a hash map
  (if (not (= nil (os/stat vidir_file_path))) (sh/rm vidir_file_path))
  (each line new
    (def j (scan-number (line 0)))
    (put new-hash j (line 1))
    (if (not (= (old j) (line 1)))
        (os/rename (old j) (line 1))))
  (loop [i :range [0 (length old)]]
    (if (= (new-hash i) nil)
        (sh/rm (old i)))))

(defn main [file & args]
  (match args
    [path] (vidir path)
    _      (vidir ".")))
