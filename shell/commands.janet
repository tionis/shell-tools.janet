(import spork/argparse)

(def- colors
  {:black   "\e[0;30m"
   :red     "\e[0;31m"
   :green   "\e[0;32m"
   :yellow  "\e[0;33m"
   :blue    "\e[0;34m"
   :magenta "\e[0;35m"
   :cyan    "\e[0;36m"
   :white   "\e[0;37m"})

(defn- color [col text]
  (unless (os/isatty) (break text))
  (string (get colors col (colors :white)) text (colors :white)))

(defn- pad-right
  "Pad a string on the right with some spaces."
  [str n]
  (def len (length str))
  (if (>= len n)
    str
    (string str (string/repeat " " (- n len)))))

(defn- doc-string-to-cli-help [command indentation has-argparse func-name docstring]
  (def lines (string/split "\n" docstring))
  (def out @"")
  (buffer/push out
    (string/repeat " " indentation)
    (color :cyan command) " ")
  (if has-argparse
    (buffer/push out
      (string/join
        (map |(string/format "%j" $0) (slice (parse (first lines)) 2 -1))
             " ") "\n")
    (buffer/push out
      (string/join
        (map |(string/format "%j" $0) (slice (parse (first lines)) 1 -1))
             " ") "\n"))
  (each line (slice lines 2 -2)
    (buffer/push out (string/repeat " " (+ indentation 2)) line "\n"))
  (buffer/push out (string/repeat " " (+ indentation 2)) (last lines))
  out)

(defn- argparse-params-to-cli-help [indentation options]
  (def out @"")
  (def flags @"")
  (def opdoc @"")
  (def reqdoc @"")
  (loop [[name handler] :in (sort (pairs options))]
    (def short (handler :short))
    (when short (buffer/push-string flags short))
    (when (string? name)
      (def kind (handler :kind))
      (def usage-prefix
        (string
          ;(if short [" -" short ", "] [(string/repeat " " (+ indentation 2))])
          "--" name
          ;(if (or (= :option kind) (= :accumulate kind))
             [" " (or (handler :value-name) "VALUE")
              ;(if-let [d (handler :default)]
                 ["=" d]
                 [])]
             [])))
      (def usage-fragment
        (string
          (pad-right (string usage-prefix " ") 45)
          (if-let [h (handler :help)] h "")
          "\n"))
      (buffer/push-string (if (handler :required) reqdoc opdoc)
                          usage-fragment)))
  (unless (empty? reqdoc)
    (buffer/push out (string/repeat " " indentation) "Required:\n")
    (buffer/push out reqdoc))
  (unless (empty? opdoc)
    (buffer/push out (string/repeat " " indentation) "Optional:\n")
    (buffer/push out opdoc))
  out)

(defn- generate-help [desc commands]
  (def out @"")
  (def indentation 2)
  (buffer/push out desc "\nAvailable commands:\n")
  (eachk command commands
    (def options (get-in commands [command :options]))
    (buffer/push out
                 (doc-string-to-cli-help
                   command
                   indentation
                   (truthy? options)
                   (get-in commands [command :func-name])
                   (get-in commands [command :doc])))
    (if options
      (buffer/push out
                   "\n"
                   (argparse-params-to-cli-help
                     (+ indentation 2)
                     options))
      (buffer/push out "\n")))
  out)

(defn commands
  `simple cli wrapper for subcommand based scripts
  allows defining funcs following the pattern of cli/name
  and generates command structure for it automatically
  using the functions name and using the docstring as
  help message. The name may be overriden by the :name
  metadata of the function
  if metadata :options is defined it uses it as input map
  for spork/argparse/argparse and passes the parsed args
  table a first argument to function
  Spcifying a description via the :desc named argument
  is recommended`
  [&named env args desc func-grammar]
  (default desc "this tool has no description at the moment")
  (default env (curenv))
  (default args (dyn *args*))
  (default func-grammar (peg/compile ~(* "cli/" (capture (to -1)))))
  (def commands @{})
  (loop [[binding meta] :pairs env
         :when (symbol? binding)
         :when (function? (get meta :value))
         :let [func-name (string binding)
               name (or
                      (first
                        (peg/match func-grammar
                                   func-name)))
               name-override (get meta :name)
               options (get meta :options)
               func (get meta :value)
               help (get meta :doc)]
         :when name
         ]
    (put commands
         (or name-override name)
         {:doc help
          :func-name func-name
          :options (if options (merge {:default {:kind :accumulate}} options))
          :func func}))
  (def subcommand (get args 1 nil))
  (def subcommand/args (if (> (length args) 2)
                         (slice args 2 -1)
                         []))
  (def command (get commands subcommand
                    {:func (fn [& _] (prin (generate-help desc commands)))}))
  ((command :func) ;(if (command :options)
                     (let [parsed (argparse/argparse
                                    desc
                                    :args [(args 0) ;subcommand/args]
                                    ;(mapcat identity (pairs (command :options))))]
                       (unless parsed (os/exit 0))
                       [parsed ;(parsed :default)])
                     subcommand/args)))
