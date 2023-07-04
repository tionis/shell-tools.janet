(import spork/sh)
(use ./which)

(defn available?
  `check if host is connectable using ssh-config`
  [host]
  (def ssh-opts @["-o" (string "ConnectTimeout=" 5)])
  (def proc (os/spawn ["ssh" ;ssh-opts host "echo" "pong"] :p {:out :pipe :err :pipe}))
  (def buf @"")
  (ev/gather
    (:read (proc :out) :all buf)
    (:read (proc :err) :all buf)
    (:wait proc))
  (def grammar
    ~{:main (some :line)
      :line (* (* (any (* (not (+ "pong" "sftp" "denied")) 1)) (capture (+ "pong" "sftp" "denied"))) (any 1) (+ "\n\r" "\n" -1))})
  (var success false)
  (case (first (peg/match grammar buf))
    "pong" (set success true)
    "denied" (set success true)
    "sftp" (set success true))
  success)
