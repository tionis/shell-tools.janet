(def grammar
  (peg/compile
    ~{:key (capture (to "="))
      :ws (set " \t\r\n")
      :escape (* "\\" (capture 1))
      :dq-string (accumulate (* "\"" (any (+ :escape (if-not "\"" (capture 1)))) "\""))
      :sq-string (accumulate (* "'" (any (if-not "'" (capture 1))) "'"))
      :token-char (+ :escape (* (not :ws) (capture 1)))
      :token (accumulate (some :token-char))
      :value (+ :dq-string :sq-string :token)
      :line (* :key "=" :value (+ "\n" -1))
      :main (some :line)}))

(defn parse [data]
  (struct ;(peg/match grammar data)))
