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

(defn- argparse->cli-help [options]
  # TODO refactor this
  (def indentation 0)
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

(defn- get-cli-funcs
  [&opt env]
  (default env (curenv))
  (tabseq [[binding meta] :pairs env
           :when (get meta :cli)
           :when (symbol? binding)
           :when (function? (get meta :value))]
          binding meta))

(defn- docstring->cli-help [docstring alias has-argparse]
  (def start (if has-argparse 2 1)) # TODO replace with proper PEG grammar
  (def lines (string/split "\n" docstring))
  (def out @[])
  (array/push out
              (string/join (map |(string/format "%j" $0)
                                (slice (parse (first lines)) start -1))
                           " "))
  (def rest @[])
  (when (> (length lines) 2)
    (each line (slice lines 2 -1)
      (array/push out (string "  " line))))
  (if (> (length alias) 0)
    (array/push out (string "aliases: [" (string/join alias ", ") "]")))
  (string/join out "\n"))

(defn print-help [x & args]
  (print (get-in x [:help :description]))
  (eachk name x
    (when-let [help-str (get-in x [name :help])
               help (string/split "\n" help-str)
               prefix-no-color (string "  " name " - ")
               prefix (string "  " (color :cyan name) " - ")
               indent (string/repeat " " (length prefix-no-color))]
      (print prefix (first help))
      (each line (slice help 1 -1)
        (print indent line)))))

(defn split-at-double-dash
  [{:func func :argparse argparse :args args}]
  (def index (index-of "--" args))
  (unless index (error "could not find -- in input args"))
  (if argparse
    (func argparse (slice args 0 index) (slice args (inc index) -1))
    (func (slice args 0 index) (slice args (inc index) -1))))

# TODO missing features:
# handle functions with named arguments by auto-generating argparse
# allow adding type information to functions via argument metadata
# use the same metadata to also define descriptions and maybe other
# data about the arguments (this approach might also be used for 
# multimethods in janet-tools)
(defn commands
  `Simple cli wrapper for subcommand based scripts that allows defining functions to use as subcommands.
  If no funcs are given as input alls funcs of the current environment that have the :cli metadata set to true are used.
  by using the functions name as command name and docstring as help message.
  Following function metadata keys can also be added:
   :name - to override the name of the subcommand
   :alias - a list of aliases for the subcommand
   :cli/doc - override docstring for cli help
   :cli/func - a function that is called instead of the real func
               is passed a single struct as input with:
                :args for the input-args
                :argparse - the output of argparse if :options was used
                :func - the original function
   :options - if defined it is used as a input map for spork/argparse to parse input args
              the result of this parsing is added as first argument when invoking the function
   TODO: will add some automatic or definable argument type conversion and handling of named arguments etc. 
  Spcifying a description via the :desc named argument is recommended`
  [&named args desc funcs env]
  (default desc "this tool has no description at the moment")
  (default args (dyn *args*))
  (default funcs (get-cli-funcs env))
  (defn alias [target]
    {:alias target
     :func (fn [x & args]
             ((get-in x [target :func]) x ;args))})
  (def commands
    @{:help
      {:help `show this help`
       :description desc
       :func print-help}
      :default
      (alias :help)})
  (loop [[binding meta] :pairs funcs
         #:when (symbol? binding)
         :when (function? (get meta :value))
         :let [name (or (get meta :name) (keyword binding))
               options (get meta :options)
               cli-func (get meta :cli/func)
               raw-func (get meta :value)
               aliases (get meta :alias [])
               docstr (or (get meta :cli/doc)
                          (docstring->cli-help (get meta :doc)
                                               aliases
                                               (truthy? options)))]]
    (def help (string docstr
                      (if options
                        (argparse->cli-help options)
                        "")))
    (def func
      (if cli-func
        (fn [_ & raw_args]
          (def [args argparse]
            (if options
              (let [parsed (argparse/argparse help :args raw_args ;(mapcat identity (pairs options)))]
                (unless parsed (break 0))
                [[;(get parsed :default []) ;(get parsed :rest [])]
                 parsed])
              [raw_args nil]))
            (cli-func {:func raw-func :args args :argparse argparse}))
        (fn [_ & raw_args]
          (def args
            (if options
              (let [parsed (argparse/argparse help :args raw_args ;(mapcat identity (pairs options)))]
                (unless parsed (break 0))
                [parsed ;(get parsed :default []) ;(get parsed :rest [])])
              raw_args))
          (raw-func ;args))))
    (put commands name {:help help :func func :alias aliases})
    (each alias aliases (put commands alias (alias name))))

  (def subcommand (keyword (get args 1 nil)))
  (def subcommand/args (if (> (length args) 2) (slice args 2 -1) []))
  (def command (get commands subcommand (commands :default)))
  ((command :func) commands ;subcommand/args))

(defn main
  `main func to be used with (use shell/commands)
  script description is set from (dyn :description)`
  [& args]
  (def funcs (get-cli-funcs))
  (commands :desc (dyn :description)
            :args args
            :funcs funcs))
