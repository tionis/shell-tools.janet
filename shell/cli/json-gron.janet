#!/bin/env janet
(import spork/json)
(import spork/argparse)

(def argparse-params
  [`Convert json to gron (greppable object notation)
   Takes input either via commandline args or stdin`
   "pretty" {:kind :flag
             :short "p"
             :default false
             :help "pretty print output"}
   :default {:kind :accumulate}])

(defn is-primitive? [x]
  (case (type x)
    :nil true
    :boolean true
    :number true
    :array false
    :tuple false
    :table false
    :struct false
    :string true
    :buffer true
    :symbol true
    :keyword true
    :function true
    :cfunction true
    :fiber true
    true))

(defn- prefix/join [prefix key]
  (def num? (= (type key) :number))
  (def prefix-empty? (= prefix ""))
  (def ret @"")
  (buffer/push ret prefix)
  (if (and (not prefix-empty?)
           (not num?))
    (buffer/push ret "/"))
  (if num?
    (buffer/push ret "[" (string key) "]")
    (buffer/push ret key))
  ret)

(defn to-gron [prefix x &named pretty]
  (def ret @"")
  (if (is-primitive? x)
    (if pretty
      (buffer/push ret (string/format "%s = %P\n" prefix x))
      (buffer/push ret (string/format "%s = %j\n" prefix x)))
    (eachk key x (buffer/push ret (to-gron (prefix/join prefix key) (x key) :pretty pretty))))
  ret)

(defn main [_ & args]
  (def res (argparse/argparse ;argparse-params))
  (unless res (os/exit 1))

  (->> (if (first (res :default)) (string/join (res :default) " ") (file/read stdin :all))
       (json/decode)
       (|(to-gron "" $0 :pretty (res "pretty")))
       (prin)))
