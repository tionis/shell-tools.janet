(import toolbox/uri)
(import spork/misc)

(def remote-scp-peg
  (peg/compile
    ~{:user (capture (to "@"))
      :host (capture (to ":"))
      :path-part (* (capture (to (+ "/" -1))) (+ "/" -1))
      :path (replace (some :path-part)
                     ,(fn [& x] x))
      :main (replace (* :user "@" :host ":" :path)
                     ,|{:user $0
                        :host $1
                        :path $2})}))

(defn- remote/parse
  `Parse remote url into it's components`
  [remote]
  (def peg-res (first (peg/match remote-scp-peg remote)))
  (if peg-res
    {:scheme "scp" :host (peg-res :host) :path (peg-res :path) :user (peg-res :user)}
    (let [uri-res (uri/parse remote)]
      {:scheme (uri-res :scheme)
       :host (uri-res :host)
       :user (uri-res :userinfo)
       :path (first (peg/match ~{:path-part (* (capture (to (+ "/" -1))) (+ "/" -1))
                                  :main (replace (* (opt "/") (some :path-part))
                                                 ,(fn [& x] x))}
                               (uri-res :path)))})))

(defn get-name [remote]
  (misc/trim-suffix ".git" (last ((remote/parse remote) :path))))

(setdyn 'parse (dyn 'remote/parse))
