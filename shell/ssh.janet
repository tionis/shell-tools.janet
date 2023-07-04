(import spork/sh)
(use ./which)

(defn available?
  `check if host is connectable using ssh-config`
  [host]
  (unless (which "ssh-ping") (error "runtime dependency ssh-ping from ssh-tools not met"))
  (= (os/execute ["ssh-ping" "-c" "1" "-q" host] :p {:out (sh/devnull)}) 0))
