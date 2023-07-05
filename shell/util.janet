(defmacro alias [new old] # TODO rewrite function name in docstring
  ~(setdyn ,new (dyn ,old)))


(defn func/meta
  `parses the function metadata using disasm returning a struct with
  :kind set to either :structarg`
  [func]
  (def meta (disasm func))
  (def ret @{})
  (put ret :order (map |($0 3) (meta :symbolmap)))
  (cond
    (meta :structarg)
    (do
      (def arr (map hash (ret :order))) # Not an ideal solution but the index-of check below cannot find two symbols that were created seperatly, so this will have to do
      (def index (min-of (map |(index-of (hash $0) arr) (meta :constants))))
      (put ret :kind :keys)
      (each arg (slice (ret :order) 0 index)
        (put-in ret [:args arg :kind] :static))
      (each arg (slice (ret :order) index -1)
        (put-in ret [:args arg :kind] :key)))
    (meta :vararg)
    (do
      (put ret :kind :var)
      (each arg (slice (ret :order) 0 -2)
        (put-in ret [:args arg :kind] :static))
      (put-in ret [:args (last (ret :order)) :kind] :sink))
    (not= (meta :min-arity) (meta :max-arity))
    (do
      (put ret :kind :opt)
      (def index (meta :min-arity))
      (each arg (slice (ret :order) 0 index)
        (put-in ret [:args arg :kind] :static))
      (each arg (slice (ret :order) index -1)
        (put-in ret [:args arg :kind] :opt)))
    (do
      (put ret :kind :static)
      (each arg (ret :order)
        (put-in ret [:arg arg :kind] :static))))
  ret)
