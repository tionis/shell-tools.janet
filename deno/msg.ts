#!/bin/env -S deno run --allow-run --lock=deno.lock
import * as msgpack from "https://deno.land/x/msgpack@v1.2/mod.ts";

// deno-lint-ignore no-explicit-any
function concatenate(resultConstructor: any, ...arrays: any[]) {
  let totalLength = 0;
  for (const arr of arrays) {
    totalLength += arr.length;
  }
  const result = new resultConstructor(totalLength);
  let offset = 0;
  for (const arr of arrays) {
    result.set(arr, offset);
    offset += arr.length;
  }
  return result;
}

export class Stream_msg {
  #reader!: ReadableStreamDefaultReader;
  #writer!: WritableStreamDefaultWriter;
  #enc = new TextEncoder();
  #dec = new TextDecoder();
  #encoding = 1;

  constructor(
    reader: ReadableStreamDefaultReader,
    writer: WritableStreamDefaultWriter,
    encoding? : number
  ) {
    this.#reader = reader;
    this.#writer = writer;
    if(encoding){this.#encoding = encoding}
  }

  // deno-lint-ignore no-explicit-any
  async send(obj: any) {
    switch(this.#encoding){
      case 0: { // raw encoding
        const msg: string =  obj.toString()
        await this.#writer.write(new Uint32Array([msg.length]))
        await this.#writer.write(new Uint8Array([this.#encoding]))
        await this.#writer.write(this.#enc.encode(msg))
        break
      }
      case 1: { // normal json encoding
        const msg: string = JSON.stringify(obj)
        await this.#writer.write(new Uint32Array([msg.length]))
        await this.#writer.write(new Uint8Array([this.#encoding]))
        await this.#writer.write(this.#enc.encode(msg))
        break
      }
      case 2: { // msgpack encoding
        const msg: Uint8Array = msgpack.encode(obj)
        await this.#writer.write(new Uint32Array([msg.length]))
        await this.#writer.write(new Uint8Array([this.#encoding]))
        await this.#writer.write(msg)
        break
      }
      case 3: {
        throw("unsupported encoding: jdn")
      }
      default: {
        throw("unknown encoding: " + this.#encoding)
      }
    }
  }

  async recv() {
    const first_chunk: ReadableStreamDefaultReadResult<Uint8Array> = await this
      .#reader.read()!;
    const msg_len: Uint8Array = first_chunk.value?.slice(0, 4)!;
    let length = 0;
    length += msg_len[0];
    if (msg_len[1]) length += msg_len[1] * 256;
    if (msg_len[2]) length += msg_len[2] * 65536;
    if (msg_len[3]) length += msg_len[3] * 16777216;
    const msg_type: Uint8Array = first_chunk.value?.slice(4, 5)!;
    let msg: Uint8Array = first_chunk.value?.slice(5)!;
    while (msg.byteLength < length) {
      const next_msg: ReadableStreamDefaultReadResult<Uint8Array> = await this.#reader.read();
      if (next_msg.value != undefined) {
        msg = concatenate(Uint8Array, msg, next_msg.value);
      }
    }
    switch (msg_type[0]) {
      case 0: { // raw = no encoding
        return this.#dec.decode(msg)
      }
      case 1: { // Normal json encoding
        return JSON.parse(this.#dec.decode(msg))
      }
      case 2: { // msgpack encoding
        return msgpack.decode(msg)
      }
      case 3: { // JDN
        throw("unsupported type: jdn")
      }
      case 4: { // error
        throw(this.#dec.decode(msg))
      }
      default: {
        throw ("unknown type")
      }
    }
  }

  async close(){
    await this.#writer.close()
    await this.#reader.cancel()
  }
}

export class AOP {
  #process!: Deno.ChildProcess;
  #messenger!: Stream_msg;
  constructor(program: string, args: Array<string>) {
    this.#process = new Deno.Command(program, {
      args: args,
      stdin: "piped",
      stdout: "piped",
    }).spawn();
    const reader = this.#process.stdout.getReader();
    const writer = this.#process.stdin.getWriter();
    this.#messenger = new Stream_msg(reader, writer);
  }

  // deno-lint-ignore no-explicit-any
  async send(obj: any) {
    return await this.#messenger.send(obj)
  }
  async recv() {
    return await this.#messenger.recv()
  }
  async status() {
    return await this.#process.status
  }
  async close() {
    await this.#messenger.close();
    //this.#process.kill()
  }
}
