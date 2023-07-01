(import ./util :prefix "" :export true)
(import ./commands :export true)
(import ./which :prefix "" :export true)
(import ./screens :export true)
(import ./dot-env :export true)
(import ./ts :export true)
(import ./os :export true)
(import ./path :export true)

(defn pp
  "pretty print with colors is os/isatty truthy"
  [x]
  (printf (if (os/isatty) "%M" "%j") x))

(defn ppe
  "pretty print to stderr with colors is os/isatty truthy"
  [x]
  (eprintf (if (os/isatty) "%M" "%j") x))

(alias 'commands 'commands/commands)
