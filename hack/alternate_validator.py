#!/usr/bin/env python3
from __future__ import annotations

from typing import BinaryIO
import json
import re
import sys


class NotValid(ValueError):
    req_name: str | None

    def __init__(self, msg: str, req_name: str | None) -> None:
        super(NotValid, self).__init__(msg)
        self.req_name = req_name


def validate_one(req: bytes) -> bytes:
    if req == b"\n":
        return req
    start = re.match(rb"\A(?P<name>\w+)(?P<markers>:+)", req, re.MULTILINE | re.DOTALL)
    if not start:
        raise NotValid("input is not a validation request or newline", req_name=None)
    req_name = start.group("name").decode()
    remaining = req[len(start.group(0)) :]
    for i in range(len(start.group("markers"))):
        entry = re.match(
            rb"\x1Ej(?P<data>[^\x1E]*)", remaining, re.MULTILINE | re.DOTALL
        )
        if not entry:
            raise NotValid(
                f"entry {i} does not have the expected entry header", req_name=req_name
            )
        try:
            json.loads(entry.group("data"))
        except ValueError as e:
            raise NotValid(
                f"entry {i} data is not valid JSON: {e}", req_name=req_name
            ) from e
        remaining = remaining[len(entry.group(0)) :]
    if remaining != b"":
        raise NotValid(
            "request has trailing content after the final entry", req_name=req_name
        )
    return start.group(0)


def validate_all(input: BinaryIO, output: BinaryIO) -> None:
    buffer = b""
    while True:
        try:
            i = buffer.index(b"\x00")
        except ValueError:
            read = input.read(1)
            if len(read) == 0:
                return
            buffer += read
            continue
        req, buffer = buffer[:i], buffer[i + 1 :]
        if req == b"":
            sys.stderr.buffer.write(b"Skipping empty request\n")
            sys.stderr.buffer.flush()
            continue
        try:
            resp = validate_one(req)
            output.write(resp)
            output.write(b"\x00")
            output.flush()
        except NotValid as e:
            if e.req_name:
                output.write(e.req_name.encode() + b"\x00")
                output.flush()
            sys.stderr.buffer.write(f"Received invalid request: {e}\n".encode())
            sys.stderr.buffer.write(req)
            sys.stderr.buffer.write(b"\n")
            sys.stderr.buffer.flush()


if __name__ == "__main__":
    validate_all(sys.stdin.buffer, sys.stdout.buffer)
