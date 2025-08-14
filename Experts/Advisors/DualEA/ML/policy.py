import json
import os
from dataclasses import dataclass, asdict
from datetime import datetime
from typing import Optional, Dict, Any

# Default Common Files folder used elsewhere
DEFAULT_COMMON = os.path.join(os.environ.get("APPDATA", ""), "MetaQuotes", "Terminal", "Common", "Files", "DualEA")
POLICY_NAME = "policy.json"


def resolve_policy_path(common_dir: str = None) -> str:
    base = common_dir or DEFAULT_COMMON
    os.makedirs(base, exist_ok=True)
    return os.path.join(base, POLICY_NAME)


@dataclass
class Policy:
    version: str
    timestamp: str
    min_confidence: float = 0.55
    # Optional: per-slice overrides in future
    overrides: Optional[Dict[str, Any]] = None
    # Optional: list of slice probabilities
    slice_probs: Optional[list[Dict[str, Any]]] = None

    def to_json(self) -> str:
        return json.dumps(asdict(self), indent=2)


def write_policy(min_confidence: float, common_dir: str = None, version: str = "1.0.0", slice_probs: Optional[list[Dict[str, Any]]] = None) -> str:
    ts = datetime.utcnow().isoformat() + "Z"
    policy = Policy(version=version, timestamp=ts, min_confidence=min_confidence, slice_probs=slice_probs)
    path = resolve_policy_path(common_dir)
    with open(path, "w", encoding="utf-8") as f:
        f.write(policy.to_json())
    return path
