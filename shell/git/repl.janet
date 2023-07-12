(import spork/getline)
(import spork/sh)
(use ../exec)
(use ./init)

(defn repl []
  (exec "git" "version")
  (print "type 'ls' to ls files below current directory, '!command' to execute any command or just 'subcommand' to execute any git subcommand")
  (forever
    (def cur (git "rev-parse" "--abbrev-ref" "HEAD"))
    (def resp @"")
    ((getline/make-getline # TODO handle history
       getline/default-autocomplete-context # TODO integrate shlex here?
       (fn [prefix &] []) # TODO auto generate some real auto suggestions here
       (fn [prefix &] (sh/exec-slurp "man" prefix))) # TODO only use man if starts with ! else use man git-something
     (string "git " cur "> ")
     resp)
    (case (string resp)
      "ls" (exec "git" "ls-files")
      ""   (os/exit 0)
      "exit" (os/exit 0)
      ":q" (os/exit 0)
      (cond
        (peg/match ~(* "!" (any 1) -1) resp) (os/execute [;(sh/split (slice resp 1 -1))] :p)
        (peg/match ~(* "git" (any 1) -1) resp) (os/execute [;(sh/split resp)] :p)
        (os/execute ["git" ;(sh/split resp)] :p)))))
