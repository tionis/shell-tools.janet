#!/bin/env janet
(import spork/json)
(import spork/argparse :prefix "")

(def argparse-params
  [(string "A simple jq replacement\n"
           "The arguments are intepreted as a janet function body\n"
           "with an input key that provides the json input from stdin as a map\n"
           "the return value of the function body is then printed")
   "output" {:kind :option
             :short "o"
             :default "json"
             :help "Output type, hast to be one of json, jdn or raw"}
   "pretty" {:kind :option
             :short "p"
             :default true
             :help "pretty print output"}
   :default {:kind :accumulate}])

(defn main [_ & args]
  (def res (argparse ;argparse-params))
  (unless res (os/exit 1))

  (def command (string/join ["(fn [x]" ;(res :default) ")"] " "))
  (def input (json/decode (file/read stdin :all) true))
  (def output ((eval-string command) input))
  (case (string/ascii-lower (res "pretty"))
    "true"  (setdyn :pretty true)
    "yes"   (setdyn :pretty true)
    "y"     (setdyn :pretty true)
    "false" (setdyn :pretty false)
    "no"    (setdyn :pretty false)
    "n"     (setdyn :pretty false))
  (case (res "output")
    "json" (if (dyn :pretty)
               (print (json/encode output "  "))
               (print (json/encode output)))
    "jdn"  (if (dyn :pretty)
               (printf "%P" output)
               (printf "%j" output))
    "raw"  (print output)
    (error "Unknown output type")))
  #   (print (code 
  #                (json/decode (file/read stdin :all))))
  #   (print (json/encode (code (string/join (res :default) " ")
  #                             (json/decode (file/read stdin :all)))))))
