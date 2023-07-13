#!/bin/env janet
# TODO still has quite a few bugs
(defn and_handler [lines_1 lines_2]
  (def lines_2_map @{})
  (each line lines_2 (put lines_2_map line true))
  (each line lines_1
    (if (lines_2_map line)
        (print line))))

(defn not_handler [lines_1 lines_2]
  (def lines_2_map @{})
  (each line lines_2 (put lines_2_map line true))
  (each line lines_1
    (if (not (lines_2_map line))
        (print line))))


(defn or_handler [lines_1 lines_2]
  (def lines_1_map @{})
  (each line lines_1 (put lines_1_map line true))
  (each line lines_1 (print line))
  (each line lines_2
    (if (not (lines_1_map line))
        (print line))))

(defn xor_handler [lines_1 lines_2]
  (def lines_1_map @{})
  (each line lines_1 (put lines_1_map line true))
  (def lines_2_map @{})
  (each line lines_2 (put lines_2_map line true))
  (each line lines_1
    (if (not (lines_2_map line))
        (print line)))
  (each line lines_2
    (if (not (lines_1_map line))
        (print line))))

(defn print_help []
  (print "Check man page for help"))

(defn get_file [file_path]
  (if (= file_path "-")
    (string/split "\n" (string/trim (file/read stdin :all)))
    (string/split "\n" (string/trim (slurp file_path)))))

(defn main [_ & args]
  (match args
    [file_1 "and" file_2] (and_handler (get_file file_1) (get_file file_2))
    [file_1 "not" file_2] (not_handler (get_file file_1) (get_file file_2))
    [file_1 "or"  file_2] (or_handler (get_file file_1) (get_file file_2))
    [file_1 "xor" file_2] (xor_handler (get_file file_1) (get_file file_2))
    _     (print_help)))
