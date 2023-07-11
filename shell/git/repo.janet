(use ./init)

(def age
  [&opt dir]
  # TODO rewrite as stream?
  (def lines (string/split "\n" (gitd dir "log" "--reverse" "--pretty=oneline" "--format=%ar")))
  (print (last lines)))
