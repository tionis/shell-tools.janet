#!/bin/env janet
(import spork/base64)
(import spork/rawterm)
(import spork/sh)

(defn main [_ & args]
  (def id (string/replace "/" "-" (base64/encode (os/cryptorand 12))))
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
    (os/spawn ["ctpv" "-s" id] :p))

  (os/execute ["fzf" ;pv "--reverse" ;args] :p {:in stdin})

  (if img?
    (os/execute ["ctpv" "-e" id] :p)))
