(declare-project
  :name "shell-tools"
  :description "some tools to make working in a shell easier"
  :dependencies ["https://github.com/janet-lang/spork"
                 "https://tasadar.net/tionis/jeff"
                 "https://tasadar.net/tionis/janet-tools"
                 #"https://github.com/pyrmont/watchful" # TODO allow watching singular files
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
    :hardcode-syspath true
    :is-janet true))

(each f (if (os/stat "man") (os/dir "man") [])
  (declare-manpage # Install man pages # TODO auto generate from module if not existant?
    (string "man/" f)))

(declare-source # Declare source files to be imported by other janet based scripts
  :source ["shell"])

(declare-native
  :name "shell/ctrl-c/native"
  :source ["src/ctrl.c"])

(when (index-of (os/which) [:posix :linux :macos])
  # if creating executable use add :deps [(posix-spawn :static)] etc
  # to declare-executable to handle compile steps correctly
  (def posix-spawn
    (declare-native
      :name "shell/posix_spawn/native"
      :source ["src/posix-spawn.c"]))
  (declare-source
    :prefix "shell"
    :source ["src/posix-spawn.janet"])
  (def sh
    (declare-native
      :name "shell/sh/native"
      :source ["src/sh.c"]))
  (declare-source
    :prefix "shell"
    :source ["src/sh.janet"]))
