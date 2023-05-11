(defn exec [& argv]
  (when (not= (os/execute [;argv] :p) 0)
    (error (string "command '" (string/join argv " ") "' failed"))))
