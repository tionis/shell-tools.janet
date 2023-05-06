#!/bin/env janet
(import ../screens)
(defn main [& _]
  (printf "%P" (screens/get-all)))
