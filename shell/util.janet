(defmacro alias [new old] # TODO rewrite function name in docstring
  ~(setdyn ,new (dyn ,old)))
