#!/usr/bin/env python3
"""
JavDB mobile CDN image decryptor.

The mobile API returns URLs like:
  https://tp.spfcas.com/rhe951l4q/covers/xw/XWYgG.jpg

Those bytes are not a directly displayable JPEG. Static analysis of
flutter_cache_manager's patched _saveFileAndPostUpdates stream mapper shows the
mobile image payload format:

  - for image URLs ending in jpg/jpeg/png/webp/gif, the first response byte is
    an XOR key when it is less than 0xff
  - the key byte is dropped
  - every remaining byte is XORed with that key before being written to cache

For already-displayable JPEG data, the first byte is 0xff, so the app leaves
the payload unchanged.
"""

from __future__ import annotations

import argparse
import os
import sys
import urllib.parse
import urllib.request


DEFAULT_WEB_IMAGE_PREFIX = "https://c0.jdbstatic.com/"
MOBILE_CDN_HOST = "tp.spfcas.com"
MOBILE_CDN_PATH_PREFIX = "/rhe951l4q/"
IMAGE_SUFFIXES = (".jpg", ".jpeg", ".png", ".webp", ".gif")


def resolve_display_url(
    url: str, web_image_prefix: str = DEFAULT_WEB_IMAGE_PREFIX
) -> str:
    """Rewrite a mobile CDN image URL to the displayable web image endpoint."""
    parsed = urllib.parse.urlparse(url)
    if parsed.netloc != MOBILE_CDN_HOST:
        return url
    if not parsed.path.startswith(MOBILE_CDN_PATH_PREFIX):
        return url

    relative_path = parsed.path[len(MOBILE_CDN_PATH_PREFIX) :]
    base = web_image_prefix.rstrip("/") + "/"
    resolved = urllib.parse.urljoin(base, relative_path)

    if parsed.query:
        resolved += "?" + parsed.query
    return resolved


def looks_like_image_url(url: str) -> bool:
    path = urllib.parse.urlparse(url).path.lower()
    return path.endswith(IMAGE_SUFFIXES)


def decrypt_mobile_image_bytes(data: bytes) -> bytes:
    """Apply the APK cache-manager image stream transform to a full payload."""
    if not data:
        raise ValueError("empty image payload")

    key = data[0]
    if key >= 0xFF:
        return data

    return bytes(byte ^ key for byte in data[1:])


def download(url: str) -> bytes:
    """Download bytes with a browser-like user agent."""
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as response:
        return response.read()


def output_path_for_url(url: str) -> str:
    name = os.path.basename(urllib.parse.urlparse(url).path) or "image.jpg"
    stem, ext = os.path.splitext(name)
    if not ext:
        ext = ".jpg"
    return f"{stem}_display{ext}"


def validate_image(data: bytes) -> None:
    if data.startswith(b"\xff\xd8\xff"):
        return
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return
    if data.startswith(b"RIFF") and data[8:12] == b"WEBP":
        return
    if data.startswith((b"GIF87a", b"GIF89a")):
        return
    raise ValueError(f"decrypted data is not a supported image: {data[:12].hex()}")


def save_decrypted_image(url: str, output_path: str | None = None) -> dict[str, object]:
    """Download, decrypt, validate, and save a mobile CDN image."""
    encrypted = download(url)
    data = decrypt_mobile_image_bytes(encrypted) if looks_like_image_url(url) else encrypted
    validate_image(data)

    if output_path is None:
        output_path = output_path_for_url(url)

    with open(output_path, "wb") as handle:
        handle.write(data)

    return {
        "input_url": url,
        "output": output_path,
        "key": encrypted[0],
        "encrypted_size": len(encrypted),
        "decrypted_size": len(data),
    }


def save_display_image(
    url: str,
    output_path: str | None = None,
    web_image_prefix: str = DEFAULT_WEB_IMAGE_PREFIX,
) -> dict[str, object]:
    """Resolve and save a displayable web image. Kept as an explicit fallback."""
    display_url = resolve_display_url(url, web_image_prefix)
    data = download(display_url)
    if not data.startswith(b"\xff\xd8\xff"):
        raise ValueError(f"downloaded data is not JPEG: {data[:8].hex()}")

    if output_path is None:
        output_path = output_path_for_url(display_url)

    with open(output_path, "wb") as handle:
        handle.write(data)

    return {
        "input_url": url,
        "display_url": display_url,
        "output": output_path,
        "size": len(data),
    }


def inspect_mobile_header(url: str) -> dict[str, object]:
    """Download a mobile CDN payload and report the recovered image header."""
    encrypted = download(url)
    decrypted = decrypt_mobile_image_bytes(encrypted)
    return {
        "input_url": url,
        "key": encrypted[0],
        "encrypted_head": encrypted[:20].hex(),
        "decrypted_head": decrypted[:20].hex(),
        "is_jfif": decrypted.startswith(b"\xff\xd8\xff\xe0")
        and decrypted[6:11] == b"JFIF\x00",
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", help="mobile CDN or display CDN image URL")
    parser.add_argument("output", nargs="?", help="output JPEG path")
    parser.add_argument(
        "--web-prefix",
        default=DEFAULT_WEB_IMAGE_PREFIX,
        help=f"display image prefix for --web-fallback, default: {DEFAULT_WEB_IMAGE_PREFIX}",
    )
    parser.add_argument(
        "--web-fallback",
        action="store_true",
        help="rewrite to web_image_prefix instead of decrypting mobile CDN bytes",
    )
    parser.add_argument(
        "--inspect-header",
        action="store_true",
        help="show mobile CDN header XOR evidence instead of saving an image",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        if args.inspect_header:
            info = inspect_mobile_header(args.url)
            print(f"Input: {info['input_url']}")
            print(f"XOR key: 0x{info['key']:02x}")
            print(f"Encrypted head: {info['encrypted_head']}")
            print(f"Decrypted head: {info['decrypted_head']}")
            print(f"JFIF: {info['is_jfif']}")
            return 0

        if args.web_fallback:
            result = save_display_image(args.url, args.output, args.web_prefix)
            print(f"Input: {result['input_url']}")
            print(f"Display URL: {result['display_url']}")
            print(f"Output: {result['output']}")
            print(f"Size: {result['size']} bytes")
            return 0

        result = save_decrypted_image(args.url, args.output)
        print(f"Input: {result['input_url']}")
        print(f"XOR key: 0x{result['key']:02x}")
        print(f"Output: {result['output']}")
        print(f"Encrypted size: {result['encrypted_size']} bytes")
        print(f"Decrypted size: {result['decrypted_size']} bytes")
        return 0
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
