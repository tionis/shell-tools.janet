(def- colors
  {:black  30
   :red    31
   :green  32
   :yellow 33
   :blue   34
   :purple 35
   :cyan   36
   :white  37})

(defn color [col text &opt modifier]
  (default modifier :regular)
  (def reset "\e[0m")
  (unless (os/isatty) (break text))
  (def code (get colors col (colors :white)))
  (def prefix
    (case modifier
      :regular (string "\e[0;" code "m")
      :bold (string "\e[1;" code "m")
      :underline (string "\e[4;" code "m")
      :background (string "\e[" (+ code 10) "m")
      :high-intensity (string "\e[0;" (+ code 60) "m")
      :high-intensity-bold (string "\e[1;" (+ code 60) "m")
      :high-intensity-background (string "\e[1;" (+ code 70) "m")
      reset))
  (string prefix text reset))
