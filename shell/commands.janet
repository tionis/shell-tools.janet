(import spork/argparse)

(defn get-function-metadata [func]
  (def meta (disasm func))
  (prinf "%M" meta)
  (def ret @{})
  (put ret :arg-arr (map |($0 3) (meta :symbolmap)))
  (cond
    (meta :structarg)
    (do
      (def arr (map hash (ret :arg-arr))) # Not an ideal solution but the index-of check below cannot find two symbols that were created seperatly, so this will have to do
      (def index (min-of (map |(index-of (hash $0) arr) (meta :constants))))
      (put-in ret :kind :keys)
      (each arg (slice (ret :arg-arr) 0 index)
        (put-in ret [:args arg :kind] :static))
      (each arg (slice (ret :arg-arr) index -1)
        (put-in ret [:args arg :kind] :key)))
    (meta :vararg)
    (do
      (put-in ret :kind :var)
      (each arg (slice (ret :arg-arr) 0 -2)
        (put-in ret [:args arg :kind] :static))
      (put-in ret [:args (last (ret :arg-arr)) :kind] :sink))
    (not= (meta :min-arity) (meta :max-arity))
    (do
      (put-in ret :kind :opt)
      (def index (meta :min-arity))
      (each arg (slice (ret :arg-arr) 0 index)
        (put-in ret [:args arg :kind] :static))
      (each arg (slice (ret :arg-arr) index -1)
        (put-in ret [:args arg :kind] :opt)))
    (do
      (put-in ret :kind :static)
      (each arg (ret :arg-arr)
        (put-in ret [:arg arg :kind] :static))))
  ret)

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

(defn- doc-string-to-cli-help [command indentation has-argparse func-name docstring alias]
  (def lines (string/split "\n" (string/trimr docstring)))
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
  (if (> (length lines) 2)
    (do
      (each line (slice lines 2 -2)
        (buffer/push out (string/repeat " " (+ indentation 2)) line "\n"))
      (buffer/push out (string/repeat " " (+ indentation 2)) (last lines)))
    (buffer/popn out 1))
  (when (> (length alias) 0)
    (buffer/push out
                 "\n"
                 (string/repeat " " (+ indentation 2))
                 "aliases: ["
                 (string/join alias ", ")
                 "]"))
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
          ;(if short [(string/repeat " " (+ indentation 2)) "-" short ", "] [(string/repeat " " (+ indentation 2))])
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
    (when (not (get-in commands [command :is-alias]))
      (def options (get-in commands [command :options]))
      (if-let [help (get-in commands [command :help])]
        (buffer/push out (string/repeat " " indentation)
                     (color :cyan command)
                     " " help)
        (buffer/push out
                     (doc-string-to-cli-help
                       command
                       indentation
                       (truthy? options)
                       (get-in commands [command :func-name])
                       (get-in commands [command :doc])
                       (get-in commands [command :alias]))))
      (if options
        (buffer/push out
                     "\n"
                     (argparse-params-to-cli-help
                       (+ indentation 2)
                       options))
        (buffer/push out "\n"))))
  out)

# TODO missing features:
# handle functions with named arguments by auto-generating argparse
# allow adding type information to functions via argument metadata
# use the same metadata to also define descriptions and maybe other
# data about the arguments (this approach might also be used for 
# multimethods in janet-tools)
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
  if metadata :alias is given the function is also aliased
  under the given names
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
               aliases (get meta :alias [])
               func (get meta :value)
               help (get meta :doc)]
         :when name]
    (put commands
         (or name-override name)
         {:doc help
          :func-name func-name
          :options (if options (merge {:default {:kind :accumulate}} options))
          :func func
          :alias (filter |(string? $0) aliases)}) # filter out special aliases
    (each alias aliases
      (put commands alias {:doc help
                           :func-name func-name
                           :options (if options (merge {:default {:kind :accumulate}} options))
                           :func func
                           :is-alias true})))
  (def subcommand (get args 1 nil))
  (def subcommand/args (if (> (length args) 2)
                         (slice args 2 -1)
                         []))
  (put commands "help" {:help `show this help`
                        :func (fn [& _] (prin (generate-help desc commands)))})
  (def default-command
    (if-let [c (commands :default)]
      c
      (commands "help")))
  (def command (get commands subcommand default-command))
  ((command :func) ;(if (command :options)
                     (let [parsed (argparse/argparse
                                    desc
                                    :args [(args 0) ;subcommand/args]
                                    ;(mapcat identity (pairs (command :options))))]
                       (unless parsed (os/exit 0))
                       [parsed ;(get parsed :default [])])
                     subcommand/args)))


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

(defn main
  `main func to be used with (use shell/commands)
  script description is set from (dyn :description)`
  [& args]
  (commands :desc (dyn :description)
            :args args))
