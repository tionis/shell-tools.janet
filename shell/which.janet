(import spork/path)

(defn which-all [exe-name]
  (->> (os/getenv "PATH")
       (string/split ":")
       (distinct)
       (mapcat |(let [path (path/join $0 exe-name)]
                  (if (os/stat path) path [])))))

(defn which [exe-name] (first (which-all exe-name)))
