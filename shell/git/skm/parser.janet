(def commit-grammar (peg/compile
  ~{:main (replace (* "tree " (capture :object-id) "\n"
                      :parents
                      "author " :person "\n"
                      "committer " :person "\n"
                      (opt (* :gpgsig))
                      "\n"
                      (capture (to -1)))
                    ,(fn [& args]
                       (if (= (length args) 6)
                         {:tree (args 0) :parents (args 1) :author (args 2) :committer (args 3) :gpgsig (string/replace-all "\n " "\n" (args 4)) :message (args 5)}
                         {:tree (args 0) :parents (args 1) :author (args 2) :committer (args 3) :message (args 4)})))
    :parents (replace (any (* "parent " (capture :object-id) "\n"))
                      ,(fn [& x] x))
    :object-id (repeat 40 :w)
    :person (replace (* (capture (to (* " " :email))) " " :email " " :timestamp)
                     ,|{:name $0 :email $1 :timestamp $2})
    :email (* "<" (* (capture (any (* (not ">") 1))) ">"))
    :timestamp (replace (* (capture :unix-time) " " (capture :offset))
                        ,|{:time $0 :offset $1})
    :unix-time (repeat 10 :d)
    :offset (* (+ "+" "-") (repeat 4 :d))
    :gpgsig (+ (* "gpgsig " (capture (* "-----BEGIN SSH SIGNATURE-----" (thru "-----END SSH SIGNATURE-----\n"))))
               (* "gpgsig " (capture (* "-----BEGIN PGP SIGNATURE-----" (thru (* "-----END PGP SIGNATURE-----\n" (opt " \n")))))))
    }))

(defn parse-commit [commit]
  (first (peg/match commit-grammar commit)))

(defn render-commit [commit]
  (def out @"")
  (buffer/push out "tree " (commit :tree) "\n")
  (each parent (commit :parents) (buffer/push out "parent " parent "\n"))
  (buffer/push out "author " (get-in commit [:author :name]) " <" (get-in commit [:author :email]) "> " (get-in commit [:author :timestamp :time]) " " (get-in commit [:author :timestamp :offset]) "\n")
  (buffer/push out "committer " (get-in commit [:committer :name]) " <" (get-in commit [:committer :email]) "> " (get-in commit [:committer :timestamp :time]) " " (get-in commit [:committer :timestamp :offset]) "\n")
  (when (commit :gpgsig) (buffer/push out "gpgsig " (string/replace-all "\n" "\n " (commit :gpgsig))))
  (buffer/push out "\n" (commit :message) "\n")
  (freeze out))
