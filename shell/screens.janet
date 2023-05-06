(import spork/sh)

(defn get-all []
  (->> (sh/exec-slurp "xrandr")
       (string/split "\n")
       (filter |(string/find " connected" $0))
       (map |(string/split " " $0))
       (map |($0 0))))
       #(map |(if (= ($0 2) "primary") ($0 0) ($0 0)))))
