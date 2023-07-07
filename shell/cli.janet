(import spork/argparse)
(def cli/funcs @{})
(var cli/description "")

(defmacro defc
  "same signature as defn but add the :cli metadata and adds func to global cli/funcs"
  [name & more]
  ~(upscope
     (defn ,name :cli ,;more)
     (put cli/funcs (keyword (quote ,name)) (dyn (quote ,name)))))

(def colors
  {:black  30
   :red    31
   :green  32
   :yellow 33
   :blue   34
   :purple 35
   :cyan   36
   :white  37})

(defn- color [col text &opt modifier]
  (default modifier :regular)
  (def reset "\e[0m")
  (unless (os/isatty) (break text))
  (def code (get colors col (colors :white)))
  (def prefix
    (case modifier
      :regular (string "\e[0;" code "m")
      :bold (string "\e[1;" code "m")
      :underline (string "\e[4;" code "m")
      :background (string "\e[" (+ code 10) "m")
      :high-intensity (string "\e[0;" (+ code 60) "m")
      :high-intensity-bold (string "\e[1;" (+ code 60) "m")
      :high-intensity-background (string "\e[1;" (+ code 70) "m")
      reset))
  (string prefix text reset))

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
  (buffer/popn out 1)
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
  (def lines (string/split "\n" docstring)) # TODO handle empty docstring better (currently has empty line)
  (def out @[])
  (array/push out
    (string/join
      (map |(string/format "%j" $0)
           (slice (parse (first lines)) start -1))
      " "))
  (def rest @[])
  (when (> (length lines) 2)
    (each line (slice lines 2 -1)
      (array/push out line)))
  (if (> (length alias) 0)
    (array/push out (string "aliases: [" (string/join alias ", ") "]")))
  (string/join out "\n"))

(defn- get-func-help
  [name command &opt indent]
  (default indent 2)
  (def buf @"")
  (when-let [help-str (command :help)
             help (string/split "\n" help-str)]
    (buffer/push buf (string/repeat " " indent) (color :cyan name) " " (first help) "\n")
    (each line (slice help 1 -1)
      (buffer/push buf (string/repeat " " (+ indent 2)) line "\n")))
  buf)

(defn print-help [x &opt patt]
  # TODO add --all to list all commands regardless of structure
  (if patt
    (cond
      (x patt) (prin (get-func-help patt (x patt) 0))
      (= (last patt) (chr "/"))
      (let [commands (sort (filter |(string/has-prefix? patt $0) (keys x)))]
        (print (color :green patt))
        (each name commands # TODO only show on level deeper after prefix so test/ shows test/one and test/two but not test/hello/there/how or test/are/you use the same approach as below to mark them as expandable
          (prin (get-func-help name (x name)))))
      (error "command not found"))
    (do
      (print (get-in x [:help :description]))
      (def commands
        (->> (keys x)
             (map |(if-let [index (string/find "/" $0)]
                     {:kind :dir
                      :name (slice $0 0 (inc index))}
                     {:kind :command
                      :name $0}))
             (distinct)
             (sort-by |($0 :name))))
      (each c commands
        (case (c :kind)
          :dir (print "  " (color :green (c :name)) " show subcommands with 'help " (c :name)"'")
          :command
          (prin (get-func-help (c :name) (x (c :name)))))))))

(defn split-at-double-dash
  "to be used in :cli/func, splits the inputs args at '--' and calls func with both arg arrays"
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
       :func (fn [x &opt patt] (print-help x (if patt (keyword patt) nil)))}
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
                        (string "\n" (argparse->cli-help options))
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
    (each al aliases (put commands al (alias name))))

  (def subcommand (keyword (get args 1 nil)))
  (def subcommand/args (if (> (length args) 2) (slice args 2 -1) []))
  (def command (get commands subcommand (commands :default)))
  ((command :func) commands ;subcommand/args))

(defn description
  [desc]
  (setdyn :description desc)
  (set cli/description desc))

(defn main
  `main func to be used with (use shell/commands)
  script description is set from (dyn :description)`
  [& args]
  (def funcs
    (if (= (length cli/funcs) 0)
      (get-cli-funcs)
      cli/funcs))
  (commands :desc (or cli/description (dyn :description))
            :args args
            :funcs funcs))
