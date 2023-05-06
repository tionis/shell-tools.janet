#!/bin/env janet
(import spork/json)
(defn main [_ & args]
  (-> (if (first args) (string/join args " ") (file/read stdin :all))
      (parse)
      (json/encode "  ")
      (print)))
