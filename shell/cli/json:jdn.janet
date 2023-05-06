#!/bin/env janet
(import spork/json)
(import spork/argparse)

(def argparse-params
  [`Convert jdn to json
   Takes input either via commandline args or stdin` 
   "pretty" {:kind :flag
             :short "p"
             :default false
             :help "pretty print output"}
   :default {:kind :accumulate}])

(defn main [_ & args]
  (def res (argparse/argparse ;argparse-params))
  (unless res (os/exit 1))

  (def format-str (if (res "pretty") "%P" "%j"))

  (->> (if (first (res :default)) (string/join (res :default) " ") (file/read stdin :all))
       (json/decode)
       (printf format-str)))
