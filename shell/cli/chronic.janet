#!/bin/env janet
(defn main [_ & args]
  (def env (os/environ))
  (def streams (os/pipe))
  (put env :out (streams 1))
  (def exit_code (os/execute args :pe env))
  (ev/close (streams 1))
  (if (not (= exit_code 0)) (prin (ev/read (streams 0) :all))))
