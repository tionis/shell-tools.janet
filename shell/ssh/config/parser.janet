(import spork/path)

(def grammar (peg/compile
  ~{:include (*)
    :line (+ :include)
    :host-block (* "Host" ())
    :main (* (+ :line :host-block))}))

# (pp (peg/match grammar (slurp (path/join (os/getenv "HOME") ".ssh" "config"))))
