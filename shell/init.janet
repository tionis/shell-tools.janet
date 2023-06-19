(import ./commands :prefix "" :export true)
(import ./which :prefix "" :export true)
(import ./screens :export true)
(import ./dot-env :export true)
(import ./ts :export true)
(import ./os :export true)

(defn pp [x]
  (printf (if (os/isatty) "%M" "%j") x))
