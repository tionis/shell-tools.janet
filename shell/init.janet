(import ./util :prefix "" :export true)
(import ./which :prefix "" :export true)
(import ./screens :export true)
(import ./dot-env :export true)
(import ./ts :export true)
(import ./os :export true)
(import ./path :export true)
(import ./color :export true)

(defn pp
  "pretty print with colors is os/isatty truthy"
  [x]
  (printf (if (os/isatty) "%M" "%j") x))

(defmacro while-let [bindings & body]
  ~(while (if-let ,bindings (do ,;body true) false)))

(defn lines [stream &opt chunk-size]
  (default chunk-size 2048)
  (coro
    (var buf @"")
    (var start 0)
    (while (:read stream chunk-size buf)
      (while-let [end (string/find "\n" buf start)]
        (def result (string/slice buf 0 end))
        (set buf (buffer/slice buf (inc end)))
        (set start 0)
        (yield result))
      (set start (length buf)))
    (when (> start 0)
      (yield (string buf)))))

(defn ppe
  "pretty print to stderr with colors is os/isatty truthy"
  [x]
  (eprintf (if (os/isatty) "%M" "%j") x))
