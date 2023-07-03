#!/bin/env -S deno run --allow-run
import * as asserts from "std/testing/asserts.ts";
import {AOP, Stream_msg} from './msg.ts';
Deno.test('basic message', async () => {
  const j = new AOP("janet", [
    "-e",
    '(import ../shell/msg)' +
    '(def recv (msg/make-recv (os/open "/dev/stdin" :r)))' +
    '(def send (msg/make-send (os/open "/dev/stdout" :w)))' + 
    '(send {"test" "test_str" :val (recv)})',
  ])
  const message = {message: "Hi!", a_val: 100}
  const expected_response = {test: "test_str", val: message}
  await j.send(message)
  // deno-lint-ignore no-explicit-any
  const response: any = await j.recv()
  asserts.assertObjectMatch(response, expected_response)
  await j.close()
})
