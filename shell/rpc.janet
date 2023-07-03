# rpc.janet
# simple stream based rpc abstraction
(import ./msg)
(import ./commands)

(defn inver)

(def action/decode
  @{0 :init
    1 :init-response # function call
    2 :error # close the connection
    3 :close
    4 :ok
    5 :call})

(def action/encode
  (invert action/decode))

(def version "v0.0.1")

(defn server
  `start a stream based RPC
  in-stream/out-stream default to stdin/stdout`
  [funcs &named in-stream out-stream]
  (default in-stream (os/open "/dev/stdin" :r)) # TODO make portable for non-unix
  (default out-stream (os/open "/dev/stdout" :w))
  (def recv (msg/make-recv in-stream))
  (def send (msg/make-recv out-stream))
  # TODO wait for init, if received init send function list back
  (def meta @{})
  (loop [[name func] :pairs funcs]
    (put meta name (commands/get-function-metadata func)))
  (forever
    # wait for command
    # when function return value is channel switch to pull based thingie??? or let the user do that with functions and don't handle such cases in the protocol
    (def msg (recv))
    (try
      (case (action/decode (first msg))
        :init (if (= version (get msg 1 nil))
            (send [(action/encode :init-response) meta])
            (error "version mismatch"))
        :init-response (error "not a client")
        :error (error (get msg 1 :unknown-error))
        :close (do
                 (send [(action/encode :ok)])
                 (break))
        :ok (error "unexpected ok")
        :call (let [[name args] (get msg 1 [nil nil])]
                (def f (funcs name))
                (unless f (error "unknown function"))
                (send [(actions/encode :call-reponse) (f ;args)]))
        :call-response (error "not a client")
      ([err] (send [(action/encode :error) err])))))

(defn client
  `executes args via (os/spawn) and used stdin/stdout streams
  to initialize a api object`
  [args]
  (def proc (os/spawn arg :px {:in :pipe :out :pipe}))
  (def send (msg/make-recv (proc :in)))
  (def recv (msg/make-recv (proc :out)))
  (send [0])
  (def [err funcs] (recv))
  @{:close (fn [x]
             (:close (proc :in))
             (:close (proc :out)))
    :kill (fn [x] (os/proc-kill proc))
    :funcs funcs
    :send (fn [x msg] (send msg))
    :recv (fn [x] (recv))
    :object (fn [x]
              (def obj @{})
              (loop [[func meta] :pairs (x :funcs)]
                # TODO generate function signature from metadata definition
                (put obj func [& args] (send [1 [func args]])))
              obj)
    :call (fn [x func & args]
            (def metadata (get-in x [:funcs func]))
            (unless metadata (error "could not find function to call"))
            (send [1 [func args]]))})
