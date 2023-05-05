#!/bin/env janet
(import ../screens)
(defn main [& _]
  (pp (screens/get-all)))
