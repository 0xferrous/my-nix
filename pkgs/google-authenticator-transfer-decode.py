#!/usr/bin/env python3
"""Decode Google Authenticator transfer QR payloads to standard otpauth URIs."""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
from dataclasses import dataclass
from urllib.parse import parse_qs, quote, urlencode, urlparse, unquote


ALGORITHMS = {
    0: "SHA1",
    1: "SHA1",
    2: "SHA256",
    3: "SHA512",
    4: "MD5",
}
DIGITS = {
    0: 6,
    1: 6,
    2: 8,
}
OTP_TYPES = {
    1: "hotp",
    2: "totp",
}


class DecodeError(ValueError):
    pass


@dataclass
class OtpParameters:
    secret: bytes = b""
    name: str = ""
    issuer: str = ""
    algorithm: int = 1
    digits: int = 1
    otp_type: int = 2
    counter: int = 0


def read_varint(data: bytes, offset: int) -> tuple[int, int]:
    result = 0
    shift = 0
    while offset < len(data):
        byte = data[offset]
        offset += 1
        result |= (byte & 0x7F) << shift
        if not byte & 0x80:
            return result, offset
        shift += 7
        if shift >= 64:
            raise DecodeError("varint is too long")
    raise DecodeError("truncated varint")


def read_len(data: bytes, offset: int) -> tuple[bytes, int]:
    size, offset = read_varint(data, offset)
    end = offset + size
    if end > len(data):
        raise DecodeError("truncated length-delimited field")
    return data[offset:end], end


def skip_field(data: bytes, offset: int, wire_type: int) -> int:
    if wire_type == 0:  # varint
        _, offset = read_varint(data, offset)
        return offset
    if wire_type == 1:  # 64-bit
        return offset + 8
    if wire_type == 2:  # length-delimited
        _, offset = read_len(data, offset)
        return offset
    if wire_type == 5:  # 32-bit
        return offset + 4
    raise DecodeError(f"unsupported protobuf wire type {wire_type}")


def decode_text(value: bytes) -> str:
    return value.decode("utf-8", errors="replace")


def parse_otp_parameters(data: bytes) -> OtpParameters:
    otp = OtpParameters()
    offset = 0
    while offset < len(data):
        tag, offset = read_varint(data, offset)
        field = tag >> 3
        wire_type = tag & 0x07

        if field == 1 and wire_type == 2:
            otp.secret, offset = read_len(data, offset)
        elif field == 2 and wire_type == 2:
            value, offset = read_len(data, offset)
            otp.name = decode_text(value)
        elif field == 3 and wire_type == 2:
            value, offset = read_len(data, offset)
            otp.issuer = decode_text(value)
        elif field == 4 and wire_type == 0:
            otp.algorithm, offset = read_varint(data, offset)
        elif field == 5 and wire_type == 0:
            otp.digits, offset = read_varint(data, offset)
        elif field == 6 and wire_type == 0:
            otp.otp_type, offset = read_varint(data, offset)
        elif field == 7 and wire_type == 0:
            otp.counter, offset = read_varint(data, offset)
        else:
            offset = skip_field(data, offset, wire_type)

    if not otp.secret:
        raise DecodeError(f"OTP entry {otp.name!r} has no secret")
    return otp


def parse_migration_payload(data: bytes) -> list[OtpParameters]:
    otps: list[OtpParameters] = []
    offset = 0
    while offset < len(data):
        tag, offset = read_varint(data, offset)
        field = tag >> 3
        wire_type = tag & 0x07

        if field == 1 and wire_type == 2:
            value, offset = read_len(data, offset)
            otps.append(parse_otp_parameters(value))
        else:
            offset = skip_field(data, offset, wire_type)

    if not otps:
        raise DecodeError("payload did not contain any OTP parameters")
    return otps


def extract_uri(input_value: str) -> str:
    value = input_value.strip()
    if "otpauth-migration://" in value:
        start = value.index("otpauth-migration://")
        return value[start:].split()[0]

    if os.path.exists(value):
        try:
            with open(value, "r", encoding="utf-8") as handle:
                text = handle.read().strip()
            if "otpauth-migration://" in text:
                return extract_uri(text)
        except UnicodeDecodeError:
            pass

        try:
            scanned = subprocess.check_output(
                ["zbarimg", "--raw", "-q", value],
                text=True,
                stderr=subprocess.DEVNULL,
            )
        except FileNotFoundError as exc:
            raise DecodeError("zbarimg is not available to scan image files") from exc
        except subprocess.CalledProcessError as exc:
            raise DecodeError(f"could not scan QR image: {value}") from exc
        return extract_uri(scanned)

    raise DecodeError("input is not an otpauth-migration URI or readable file path")


def decode_payload(uri: str) -> list[OtpParameters]:
    parsed = urlparse(uri)
    if parsed.scheme != "otpauth-migration":
        raise DecodeError("expected URI scheme otpauth-migration://")

    data_values = parse_qs(parsed.query).get("data")
    if not data_values:
        raise DecodeError("migration URI is missing data= query parameter")

    encoded = unquote(data_values[0])
    encoded += "=" * (-len(encoded) % 4)
    try:
        payload = base64.urlsafe_b64decode(encoded)
    except Exception as exc:  # noqa: BLE001: provide a clean CLI error
        raise DecodeError("data= is not valid URL-safe base64") from exc
    return parse_migration_payload(payload)


def to_otpauth_uri(otp: OtpParameters) -> str:
    kind = OTP_TYPES.get(otp.otp_type, "totp")
    secret = base64.b32encode(otp.secret).decode("ascii").rstrip("=")
    algorithm = ALGORITHMS.get(otp.algorithm, "SHA1")
    digits = DIGITS.get(otp.digits, 6)

    if otp.issuer and not otp.name.startswith(f"{otp.issuer}:"):
        label = f"{quote(otp.issuer)}:{quote(otp.name)}"
    else:
        label = quote(otp.name)

    params: dict[str, str | int] = {
        "secret": secret,
        "algorithm": algorithm,
        "digits": digits,
    }
    if otp.issuer:
        params["issuer"] = otp.issuer
    if kind == "totp":
        params["period"] = 30
    else:
        params["counter"] = otp.counter

    return f"otpauth://{kind}/{label}?{urlencode(params)}"


def to_record(otp: OtpParameters) -> dict[str, str | int]:
    kind = OTP_TYPES.get(otp.otp_type, "totp")
    return {
        "type": kind,
        "name": otp.name,
        "issuer": otp.issuer,
        "secret": base64.b32encode(otp.secret).decode("ascii").rstrip("="),
        "algorithm": ALGORITHMS.get(otp.algorithm, "SHA1"),
        "digits": DIGITS.get(otp.digits, 6),
        **({"period": 30} if kind == "totp" else {"counter": otp.counter}),
        "uri": to_otpauth_uri(otp),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Decode Google Authenticator transfer QR data to otpauth:// URIs.",
        epilog="Treat output as sensitive 2FA secrets. Prefer running this offline.",
    )
    parser.add_argument(
        "input",
        nargs="?",
        help="otpauth-migration URI, text file path, image file path, or stdin if omitted",
    )
    parser.add_argument("--json", action="store_true", help="print decoded entries as JSON")
    args = parser.parse_args()

    source = args.input if args.input is not None else sys.stdin.read()

    try:
        uri = extract_uri(source)
        otps = decode_payload(uri)
    except DecodeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps([to_record(otp) for otp in otps], indent=2))
    else:
        for otp in otps:
            print(to_otpauth_uri(otp))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
