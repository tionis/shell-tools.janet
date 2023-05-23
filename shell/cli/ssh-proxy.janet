#(import ../ssh/config/parser)
(defn log [obj]
  (case (type obj)
    :string (eprint obj)
    :buffer (eprint obj)
    (eprintf "%P" obj)))

(defn main [_ host port]
  (def host (slice host 0 (- (length host) 3))) # TODO parse ssh config and replace hostname and port if needed
  (def auth (os/getenv "SSH_PROXY_AUTH"))
  (def url (string/join ["wss://ssh.tasadar.net/proxy" host port] "/"))
  (log url)
  (log ["huproxyclient" url ;(if auth ["-auth" auth] [])])
  (os/execute ["huproxyclient" url ;(if auth ["-auth" auth] [])] :p)) # TODO remove dep on huproxyclient also maybe add ssh-key based auth checked against gitea user keys
