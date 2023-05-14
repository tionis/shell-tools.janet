#!/bin/env janet
(import spork/rawterm)
(import spork/sh)

(defn roll-one-y-sided-die [y]
  (if (not (dyn :rng)) (setdyn :rng (math/rng (os/cryptorand 8))))
  (+ 1 (math/rng-int (dyn :rng) y)))

(defn main [_ & args]
  (def id (string (roll-one-y-sided-die 1000000000)))
  (def pv @[])
  (var [h w] (rawterm/size))
  (var [x y] [0 0])
  (var img? (or (> w 52) (> h 13)))

  (if img?
    (let [COLS w LINS h]
      (array/push pv "--preview-window")
      (if (or (> w (* h 3))
              (> w 169))
        (do
          (array/push pv "right:50%")
          (set x (math/floor (+ (/ COLS 2) 2)))
          (set y 1)
          (set w (math/floor (- (/ (- COLS 1) 2) 2)))
          (set h (- LINS 2)))
        (do
          (array/push pv "down:50%")
          (set x 1)
          (set y (math/floor (+ (/ LINS 2) 2)))
          (set w (- COLS 2))
          (set h (math/floor (- (/ (- LINS 1) 2) 2)))))
      (array/push pv "--preview")
      (array/push pv (string/join (map |(string $0)
                                       ["ctpv" "-c" id "&&" "ctpv" "{}" w h x y id])
                                  " "))))

  (if img?
    (os/spawn ["ctpv" "-s" id] :p {:in (sh/devnull)}))

  (os/execute ["fzf" ;pv "--reverse" ;args] :p)

  (if img?
    (os/execute ["ctpvquit" id] :p)))
