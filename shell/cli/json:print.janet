#!/bin/env janet
(import spork/json)
(defn main [_ & args]
  (print (json/encode (parse (string/join args " ")) "  ")))
