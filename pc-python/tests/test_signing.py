import time
import uuid
from pathlib import Path
from kaironagent.cloud.models import Command, CommandKind, CommandStatus
from kaironagent.security.signing import SigningVerifier

def test_signing_success(tmp_path: Path):
    secret = "a" * 64
    verifier = SigningVerifier(secret=secret, window_seconds=90, db_path=tmp_path / "test_nonces.sqlite")
    
    ts = int(time.time())
    nonce = "boot-0001"
    utterance = "masaüstündeki pdfleri topla"
    sig = SigningVerifier.compute_signature(secret, "task", nonce, ts, utterance)

    cmd = Command(
        id=uuid.uuid4(),
        kind=CommandKind.TASK,
        utterance=utterance,
        nonce=nonce,
        ts=ts,
        sig=sig,
        status=CommandStatus.PENDING
    )

    ok, reason = verifier.verify(cmd)
    assert ok, f"Doğrulama başarısız oldu: {reason}"

def test_replay_attack_rejected(tmp_path: Path):
    secret = "a" * 64
    verifier = SigningVerifier(secret=secret, window_seconds=90, db_path=tmp_path / "test_nonces.sqlite")
    
    ts = int(time.time())
    nonce = "boot-0002"
    utterance = "klasör aç"
    sig = SigningVerifier.compute_signature(secret, "task", nonce, ts, utterance)

    cmd = Command(
        id=uuid.uuid4(),
        kind=CommandKind.TASK,
        utterance=utterance,
        nonce=nonce,
        ts=ts,
        sig=sig
    )

    # İlk sefer geçmeli
    ok, _ = verifier.verify(cmd)
    assert ok

    # İkinci sefer (aynı nonce) reddedilmeli
    ok2, reason2 = verifier.verify(cmd)
    assert not ok2
    assert "Tekrar saldırısı" in reason2

def test_bad_signature_rejected(tmp_path: Path):
    secret = "a" * 64
    verifier = SigningVerifier(secret=secret, window_seconds=90, db_path=tmp_path / "test_nonces.sqlite")
    
    ts = int(time.time())
    nonce = "boot-0003"
    utterance = "klasör aç"

    cmd = Command(
        id=uuid.uuid4(),
        kind=CommandKind.TASK,
        utterance=utterance,
        nonce=nonce,
        ts=ts,
        sig="0123456789abcdef" * 4
    )

    ok, reason = verifier.verify(cmd)
    assert not ok
    assert "geçersiz" in reason

if __name__ == "__main__":
    import pytest
    import sys
    sys.exit(pytest.main(["-v", __file__]))
