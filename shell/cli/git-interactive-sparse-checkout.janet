#!/bin/env janet
(use ../git/interactive-sparse-checkout)
(defn main [_ & args]
  (interactive-sparse-checkout))
