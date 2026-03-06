#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = ROOT / "docs"
CANONICAL_DIR = DOCS_DIR / "canonical"


def git_changed(base: str, head: str):
    cmd = ["git", "diff", "--name-only", f"{base}...{head}"]
    out = subprocess.check_output(cmd, text=True, cwd=ROOT)
    return {line.strip() for line in out.splitlines() if line.strip()}


def load_allowed_tokens():
    schema = (CANONICAL_DIR / "schema.md").read_text()
    tools_obj = json.loads((CANONICAL_DIR / "tools_schemas.json").read_text())
    env_vars = (CANONICAL_DIR / "env_vars.md").read_text()
    errors = (CANONICAL_DIR / "errors.md").read_text()

    tables = set(re.findall(r"^##\s+\d+\.\d+\s+([a-z_]+)\s*$", schema, re.M))
    columns = set(re.findall(r"\|\s*([a-z_]+)\s*\|\s*[A-Z]", schema))
    tools = set(tools_obj.get("tools", {}).keys())
    tool_fields = set()
    for spec in tools_obj.get("tools", {}).values():
        tool_fields.update(spec.get("properties", {}).keys())

    env = set(re.findall(r"\|\s*([A-Z][A-Z0-9_]+)\s*\|", env_vars))
    error_codes = set(re.findall(r"\|\s*([A-Z_]+)\s*\|\s*\d{3}\s*\|", errors))

    enums_misc = {
        "active", "resolved", "escalated", "abandoned", "ai", "manual", "ai_whisper",
        "empty", "has_items", "summary_shown", "confirmed", "order_created",
        "whatsapp", "web_widget", "instagram", "customer", "agent", "system", "tool_call", "tool_result",
        "text", "image", "voice", "product_card", "carousel", "quick_reply", "order_summary", "form",
        "free", "starter", "pro", "enterprise", "pending", "paid", "failed", "cod", "online", "merchant_link",
        "pg_trgm", "pgvector", "uuid_ossp", "widget_session", "config_change",
    }
    identifiers_misc = {
        "tenant_id", "conversation_id", "customer_id", "product_id", "variant_id", "order_id",
        "idempotency_key", "delivery_name", "delivery_phone", "delivery_address", "delivery_city",
        "payment_method", "payment_status", "confirm_state", "config_version", "cart_state",
        "channel_message_id", "monthly_budget_mad", "created_at", "updated_at", "last_message_at",
        "tokens_in", "tokens_out", "latency_ms", "model_used", "routing_rules", "business_rules",
        "tools_enabled", "tool_args", "tool_name", "tool_result", "is_active", "sync_status", "last_sync_at",
        "system_prompt_override", "in_stock_only", "price_max", "cors_origins",
    }
    allowed = set(tables) | set(columns) | set(tools) | set(tool_fields) | enums_misc | identifiers_misc
    allowed_upper = env | error_codes | {"SPEC_VERSION", "SPEC_LOCK"}
    return allowed, allowed_upper


def top_level_docs_md():
    return sorted(p for p in DOCS_DIR.glob("*.md") if p.is_file())


def check_canonical_change_requires_regen(changed):
    canonical_changed = any(p.startswith("docs/canonical/") for p in changed)
    if not canonical_changed:
        return []
    required = {str(p.relative_to(ROOT)) for p in top_level_docs_md()}
    missing = sorted(required - changed)
    if missing:
        return [
            "Canonical files changed but not all top-level docs/*.md were regenerated.",
            *[f"- Missing regenerated file in diff: {m}" for m in missing],
        ]
    return []


def check_references_if_docs_changed(changed):
    docs_changed = any(p.startswith("docs/") and p.endswith(".md") for p in changed)
    if not docs_changed:
        return []

    allowed, allowed_upper = load_allowed_tokens()
    failures = []
    for p in top_level_docs_md():
        text = p.read_text()
        rel = str(p.relative_to(ROOT))

        for tok in set(re.findall(r"`([a-z][a-z0-9_]{2,})`", text)):
            if tok in allowed:
                continue
            if "_" not in tok:
                continue
            failures.append(f"{rel}: non-canonical backticked token `{tok}`")

        for tok in set(re.findall(r"`([A-Z][A-Z0-9_]{2,})`", text)):
            if tok not in allowed_upper:
                # only enforce on env/error-like backticked constants
                if "_" in tok:
                    failures.append(f"{rel}: non-canonical backticked constant `{tok}`")

    return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="origin/main")
    parser.add_argument("--head", default="HEAD")
    args = parser.parse_args()

    changed = git_changed(args.base, args.head)
    failures = []
    failures.extend(check_canonical_change_requires_regen(changed))
    failures.extend(check_references_if_docs_changed(changed))

    if failures:
        print("DOCS DRIFT CHECK: FAIL")
        for f in failures:
            print(f)
        raise SystemExit(1)

    print("DOCS DRIFT CHECK: PASS")


if __name__ == "__main__":
    main()
