#!/bin/env janet
(defn to_two_digit_string [num]
  (if (< num 9)
    (string "0" num)
    (string num)))
(defn get_date_string []
  (def date (os/date))
  (string (date :year) "-" (to_two_digit_string (+ (date :month) 1)) "-" (to_two_digit_string (+ (date :month-day) 1))
                "T"
                (to_two_digit_string (date :hours)) ":" (to_two_digit_string (date :minutes)) ":" (to_two_digit_string (date :seconds))))

(defn add-timestamps [f]
  (while true
    (def line (file/read f :line))
    (if (= line nil) (os/exit 0))
    (prin (string (get_date_string) " " line))))
