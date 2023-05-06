#!/bin/env janet
(defn main [& args]
  (match (file/read stdin :all) 
    "\n" (print "stdin empty")
    "" (print "stdin empty")
    _ (os/shell (string ;(slice args 1)))))
