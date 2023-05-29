(dyn :doc "some helpers for handling of terminal stuff")

(defn strikethrough [text] (string "\e[9m" text "\e[0m"))
(defn dim [text] (string "\e[2m" text "\e[0m"))
(defn yellow [text] (string "\e[33m" text "\e[0m"))
(defn green [text] (string "\e[32m" text "\e[0m"))
(defn red [text] (string "\e[31m" text "\e[0m"))
