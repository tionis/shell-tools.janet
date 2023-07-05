(defn inotify
  `uses inotify to watch paths and runs func on change`
  [paths func]
  # Get a file watching process
  (var pipe nil)
  (var proc nil)
  (try
    (do
      (def args ["inotifywait" "-m" "-r" ;paths "-e" "modify"])
      (set proc (os/spawn args :px {:out :pipe}))
      (print "using inotifywait")
      (set pipe :out))
    ([_]
     (def args ["fswatch" "-r" "-o" "-a"
                "-e" "4913" # vim will create a test file called "4913" for terrible reasons. Like wtf.
                "--event=Created" "--event=Updated" "--event=AttributeModified" "--event=Removed"
                "--event=Renamed"
                ;paths])
     (set proc (os/spawn args :px {:out :pipe}))
     (print "using fswatch")
     (set pipe :out)))
  (def buf @"")
  (var build-iter 0)
  (forever
    (print "Waiting...")
    (buffer/clear buf)
    (ev/read (proc pipe) 4096 buf)
    (when (empty? buf)
      (:wait proc)
      (break))
    (printf "change: %M" (map |(string/split " " $0) (string/split "\n" (string/trimr buf))))
    (func)
    (print "Rebuild " (++ build-iter))))
