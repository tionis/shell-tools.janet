(import spork/sh)

(defn git [& args]
  (sh/exec-slurp "git" ;args))

(defn gitd
  "same as git but with dir to use as working dir"
  [dir & args]
  (default dir (os/cwd))
  (sh/exec-slurp "git" "-C" dir ;args))
