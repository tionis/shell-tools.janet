(import spork/http)
(import spork/sh)
(import spork/path)
(import spork/misc)
(import spork/htmlgen)


(defn log
  [& xs]
  (if (os/isatty)
    (printf "%M" xs)
    (printf "%m" xs)))

(def water.css (slurp (path/join "assets" "water.css")))

(defn mime/get-type
  [path]
  (def resp (misc/trim-prefix (string path ":") (sh/exec-slurp "file" "--mime-type" path))))

(defn handle-file
  [path]
  {:status 200
   :body (slurp path) # TODO use chunking
   :headers {:content-type (mime/get-type path)}})

(defn handle-dir
  [path]
  (def files @[])
  (def dirs @[])
  (each entry (os/dir path)
    (def s (os/stat (path/join path entry)))
    (case (and s (s :mode))
      :file (array/push files entry)
      :directory (array/push dirs entry)))
  (sort files)
  (sort dirs)
  (def file-list
    [:ul ;(map |[:li [:a {:href (string/join ["" path $0] "/")} $0]]
               files)])
  (def dir-list
    [:ul ;(map |[:li [:a {:href (string/join ["" path $0] "/")} $0]]
               dirs)])
  (def out
    [:html {:lang "en"}
      [:head
        [:meta {:charset "UTF-8"}]
        [:meta {:name "viewport" :content "width=device-width, initial-scale=1.0"}]
        #[:meta {:http-equiv "X-UA-Compatible" :content "ie=edge"}]
        [:title (if (not= path ".") path "root")]
        [:link {:rel "stylesheet"
                :href "/water.css"}]]
       [:body
        [:h1 (if (not= path ".") path "root")]
        (if (not= path ".") [:a {:href (path/posix/normalize (path/join "" path ".."))} "go back"])
        [:h2 "dirs"]
        dir-list
        [:h2 "files"]
        file-list]])
  {:status 200
   :headers {:content-type "text/html; charset=UTF-8"}
   :body (string "<!DOCTYPE html>\n" (htmlgen/html out))})

(defn handler
  [{:buffer buf
    :connection conn
    :head-size head
    :headers headers
    :method method
    :path path-in
    :route route
    :query query
    :query-string query-str}]
  (log :path path-in)
  (case path-in
    "/water.css" (break {:body water.css
                         :status 200
                         :header {:content-type "text/css; charset=UTF-8"}}))
  (var path (misc/trim-prefix "/" path-in))
  (if (= (length path) 0) (set path "."))
  (var stat (os/stat path))
  (unless stat
    (set path (string path ".html"))
    (set stat (os/stat path)))
  (if stat
    (case (stat :mode)
      :file (handle-file path)
      :directory (if-let [index-path (path/join path "index.html")
                          index-stat (os/stat index-path)
                          is-file (= (index-stat :mode) :file)]
                   (handle-file index-path)
                   (handle-dir path)))
    {:status 404 :body "not found"}))

(defn main [myself & args]
  (print "Starting server accessable at http://localhost:8000/")
  (http/server handler "127.0.0.1" "8000"))
