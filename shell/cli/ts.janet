#!/bin/env janet
(import ../ts)
(defn main [& _]
  (ts/add-timestamps stdin))
