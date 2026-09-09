"""e-Stat 統計GIS からの zip ダウンロード共通処理。

境界データ（小地域・メッシュ）はいずれも同じダウンロードエンドポイントを使うため、
取得と検証・リトライをここに集約する。
"""

import logging
import time
import zipfile
from http.client import IncompleteRead
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

logger = logging.getLogger("pipelines")

_TRANSIENT_HTTP_CODES = {502, 503, 504}
_MAX_RETRIES = 4
_TIMEOUT = 60  # seconds


class InvalidDownload(Exception):
    """Downloaded payload is not a valid zip (e.g. truncated body or an HTML
    error/maintenance page returned with HTTP 200)."""


def download_with_retry(req: Request, dest: Path) -> None:
    """Download a zip to a file, validating it, with retry on transient errors.

    e-Stat の統計GIS は混雑時などに HTTP 200 のまま HTML のエラーページや
    途中で切れた本文を返すことがある。そのまま zipfile に渡すと BadZipFile で
    パイプライン全体が落ちるため、ダウンロード本文が本物の zip か検証し、
    不正なら一時障害として再試行する。
    """
    for attempt in range(_MAX_RETRIES):
        try:
            with urlopen(req, timeout=_TIMEOUT) as resp:
                content_type = resp.headers.get("Content-Type", "")
                data = resp.read()
            # zip のマジックバイト (PK) と Content-Type で本文を検証する。
            if "html" in content_type.lower() or not data.startswith(b"PK"):
                raise InvalidDownload(
                    f"not a zip (Content-Type={content_type!r}, {len(data)} bytes)"
                )
            dest.write_bytes(data)
            if not zipfile.is_zipfile(dest):
                dest.unlink(missing_ok=True)
                raise InvalidDownload("downloaded file failed zip integrity check")
            return
        # 応答の読み取り中に起きる失敗は URLError に包まれない。urllib が包むのは
        # 送信時の OSError だけで、getresponse() 以降はソケット層の
        # TimeoutError / ConnectionResetError と、本文が Content-Length に届かない
        # IncompleteRead がそのまま上がる。明示しないと再試行を素通りする。
        except (
            HTTPError,
            URLError,
            InvalidDownload,
            TimeoutError,
            ConnectionResetError,
            IncompleteRead,
        ) as e:
            transient = not isinstance(e, HTTPError) or e.code in _TRANSIENT_HTTP_CODES
            if not transient or attempt == _MAX_RETRIES - 1:
                raise
            reason = getattr(e, "reason", None) or getattr(e, "code", None) or e
            wait = 2**attempt
            logger.warning(
                f"  {reason}, retry in {wait}s ({attempt + 1}/{_MAX_RETRIES})"
            )
            time.sleep(wait)
