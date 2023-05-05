(declare-project
  :name "shell-tools"
  :description "some tools to make working in a shell easier"
  :dependencies ["https://github.com/janet-lang/spork"
                 "https://tasadar.net/tionis/jeff"
                 "https://github.com/pyrmont/watchful" # TODO allow watching singular files
                 ]
  :author "tionis.dev"
  :license "MIT"
  :url "https://tasadar.net/tionis/shell-tools"
  :repo "git+https://tasadar.net/tionis/shell-tools")

(each f (os/dir "shell/cli")
  (declare-executable # Install janet git tools
    :name (first (peg/match ~(* (* (capture (any (* (not ".janet") 1))) ".janet") -1) f))
    :entry (string "shell/cli/" f)
    :install true))

(each f (if (os/stat "bin") (os/dir "bin") []) # Install shell scripts
  (declare-bin
    :main (string "bin/" f)))

(each f (if (os/stat "binscript") (os/dir "binscript") [])
  (declare-binscript # Install simple janet scripts
    :main (string "binscript/" f)
    :hardcode-syspath false
    :is-janet false))

(each f (if (os/stat "man") (os/dir "man") [])
  (declare-manpage # Install man pages
    (string "man/" f)))

(declare-source # Declare source files to be imported by other janet based scripts
  :source ["shell"])

