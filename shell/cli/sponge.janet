#!/bin/env janet
(import spork/argparse :prefix "")

(def argparse-params
  ["Soak up stdin and output it when all of it was read."
   "append" {:kind :flag
             :short "a"
             :help "Open file in append only mode."}
   "file" {:kind :option
           :short "f"
           :help "Defines file to write stdout to."}])

(defn main [& _]
  (def args (argparse ;argparse-params))
  (unless args (os/exit 1))
  (if (args "file")
    (file/close
      (let [f (if (args "append") (file/open (args "file") :a) (file/open (args "file") :w))]
        (file/write f (file/read stdin :all))))
    (prin (file/read stdin :all))))
