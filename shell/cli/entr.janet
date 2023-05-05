#!/bin/env janet
(import spork/argparse :prefix "")
(import watchful)
(use sh)

(def argparse-params
  ["Execute command using sh when a file/inotify event fires changes using a configurable grace period."
   "path" {:kind :option
          :short "p"
          :default "."
          :help "The path to watch"
          :required false}
   "command" {:kind :option
              :short "c"
              :help "The command to execute using sh"
              :required true}
   "time" {:kind :option
           :short "t"
           :default 1.0
           :help "The grace period to wait to accumulate changes into one execution"
           :require false}
   "janet" {:kind :option
            :short "j"
            :help "Janet code to execute on event instead of command, will be executed without sandbox with janet-sh imported at the top level"
            :require false}
    :default {:kind :accumulate}])

# TODO fix janet code execution
(defn main [& _]
  (def args (argparse ;argparse-params))
  (unless args (os/exit 1))
  (var time 1.0)
  (if (not (= (args "time") 1.0)) (set time (scan-number (args "time"))))
  (if (args "janet")
    (watchful/watch (args "path")
                    |(do (print ($0 :type) ": " ($0 :path))
                         (eval-string (args "janet")))
                    {:elapse time})
    (watchful/watch (args "path")
                    |(do (print ($0 :type) ": " ($0 :path))
                         (os/execute ["sh" "-c" (args "command")] :p))
                    {:elapse time})))
