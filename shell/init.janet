(import ./util :prefix "" :export true)
(import ./commands :export true)
(import ./which :prefix "" :export true)
(import ./screens :export true)
(import ./dot-env :export true)
(import ./ts :export true)
(import ./os :export true)

(defn pp [x]
  (printf (if (os/isatty) "%M" "%j") x))

(defn simple
  `simple help message handler to be put at beginning of cli script execution
  with a description set to unify help messages
  if require-args is set, help message also triggers when no args were given
  if no args are give they are taken from (dyn *args*)`
  [&named desc args require-args]
  (default args (dyn *args*))
  (default desc "no description available")
  (def command
    (get @{"help" :help
           "--help" :help
           "-h" :help} (get args 1 (if require-args :specify-args nil)) nil))
  (when command
    (case command
      :help (print desc)
      :specify-args (print "specify args!\n" desc))
    (os/exit 0)))

(alias 'commands 'commands/commands)
