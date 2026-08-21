#!/usr/bin/env python3
"""Render matrix: no k8s Secret name may have two producers.

`helm lint` and `helm template` both accept the collision that produced the
2026-08-21 QITP incident, because the output is valid YAML either way. The
invariant has to be asserted on object identity instead.
"""
import subprocess
import sys

import yaml

CHART = sys.argv[1] if len(sys.argv) > 1 else "."
RELEASE = "rel"
SECRET = f"{RELEASE}-tcc-k8s-service-template-secrets"
CONFIG = f"{RELEASE}-tcc-k8s-service-template-config"
ES = ["externalSecret.enabled=true", "externalSecret.secretPath=k8s/x"]


def render(*sets: str) -> list[dict]:
    argv = ["helm", "template", RELEASE, CHART]
    for s in sets:
        argv += ["--set", s]
    proc = subprocess.run(argv, capture_output=True, text=True)
    if proc.returncode:
        print("RENDER FAILED: " + " ".join(argv))
        print(proc.stderr[-2000:])
        sys.exit(1)
    return [d for d in yaml.safe_load_all(proc.stdout) if d]


def producers(docs: list[dict]) -> dict[str, list[str]]:
    claims: dict[str, list[str]] = {}
    for d in docs:
        kind = d["kind"]
        if kind == "Secret":
            claims.setdefault(d["metadata"]["name"], []).append("chart-Secret")
        elif kind == "ExternalSecret":
            claims.setdefault(d["spec"]["target"]["name"], []).append("ExternalSecret")
        elif kind == "SecretProviderClass":
            for obj in d["spec"].get("secretObjects", []):
                claims.setdefault(obj["secretName"], []).append("vault-SPC")
    return {name: sorted(v) for name, v in claims.items() if len(v) > 1}


def container(docs: list[dict], kind: str) -> dict:
    for d in docs:
        if d["kind"] == kind:
            return d["spec"]["template"]["spec"]["containers"][0]
    raise AssertionError(f"no {kind} rendered")


def secret_refs(c: dict) -> list[str]:
    return [e["secretRef"]["name"] for e in (c.get("envFrom") or []) if "secretRef" in e]


FAILED = False


def check(label: str, got, want) -> None:
    global FAILED
    if got == want:
        print(f"PASS  {label}")
        return
    FAILED = True
    print(f"FAIL  {label}\n        got:  {got}\n        want: {want}")


def main() -> int:
    docs = render(*ES)
    check("externalSecret on: one producer per Secret name", producers(docs), {})
    check("externalSecret on: envFrom mounts the ESO Secret",
          secret_refs(container(docs, "Deployment")), [SECRET])

    docs = render(*ES, "app.type=statefulset")
    check("statefulset: one producer per Secret name", producers(docs), {})
    check("statefulset: envFrom mounts the ESO Secret",
          secret_refs(container(docs, "StatefulSet")), [SECRET])

    docs = render(*ES, "externalSecret.targetSecretName=elsewhere")
    check("ESO aimed elsewhere: chart Secret survives", producers(docs), {})
    check("ESO aimed elsewhere: envFrom mounts the chart Secret",
          secret_refs(container(docs, "Deployment")), [SECRET])

    docs = render(*ES, "secrets.vault.enabled=true")
    check("vault + ESO: one producer per Secret name", producers(docs), {})

    docs = render(*ES, "secrets.external.enabled=true", "secrets.external.secretName=x-secrets")
    check("external secretName: one producer per Secret name", producers(docs), {})

    docs = render("secrets.enabled=false", "configMap.enabled=true")
    env = container(docs, "Deployment").get("env") or []
    check("configMap without secrets: no configMapRef inside env:",
          [e for e in env if "configMapRef" in e], [])
    check("configMap without secrets: configMapRef lands in envFrom",
          container(docs, "Deployment").get("envFrom"), [{"configMapRef": {"name": CONFIG}}])

    docs = render()
    check("defaults: one producer per Secret name", producers(docs), {})
    check("defaults: envFrom mounts the chart Secret",
          secret_refs(container(docs, "Deployment")), [SECRET])

    return 1 if FAILED else 0


if __name__ == "__main__":
    sys.exit(main())
