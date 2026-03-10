import os
from . import helpers
from glob import glob


try:
    from urllib.parse import quote
except ImportError:
    from urllib import quote


def get_project_root(ctx):
    result = ctx.run("git rev-parse --show-toplevel")
    if result.ok:
        return result.stdout.splitlines()[-1]
    else:
        raise ValueError("Failed to retrieve project root folder from git command")


def get_project_version(ctx, abbrev=0, component=None):
    cmd = "git describe --tags"

    if abbrev is not None:
        cmd += " --abbrev=%s" % abbrev

    if component is not None:
        cmd += " --match='%s/*'" % component

    result = ctx.run(cmd, hide=True, warn=True)
    if result.ok:
        return result.stdout.splitlines()[-1]
    else:
        return None


def _bump_version(
    ctx,
    mode,
    current_version,
    parse,
    serialize,
    new_version=None,
    dry_run=False,
    allow_dirty=False,
):
    cmd = """
    bumpversion --list \
        --current-version {current_version} \
        --parse "{parse}" \
        --serialize "{serialize}" \
        --no-commit \
        --tag \
        --tag-name "{{new_version}}" \
        --tag-message "Release {{new_version}}" \
        {mode} \
    """.format(
        current_version=current_version, mode=mode, parse=parse, serialize=serialize
    )

    if new_version:
        cmd += " --new-version={new_version}".format(new_version=new_version)

    if dry_run:
        cmd += " --dry-run"

    if allow_dirty:
        cmd += " --allow-dirty"

    with ctx.cd(get_project_root(ctx)):
        print(cmd)
        result = ctx.run(cmd, hide=True, warn=True)
        if result.ok:
            return result.stdout.splitlines()[-1]
        else:
            raise ValueError("Failed to create version:\n" + result.stderr)


def _create_new_version(
    ctx, version, parse, serialize, dry_run=False, allow_dirty=False
):
    return _bump_version(
        ctx,
        mode="major",
        parse=parse,
        serialize=serialize,
        current_version=version,
        new_version=version,
        dry_run=dry_run,
        allow_dirty=allow_dirty,
    )


DEFAULT_PARSE_REGEX = r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)$"
DEFAULT_SERIALIZE = r"{major}.{minor}.{patch}"


def release(
    ctx,
    mode,
    version,
    component=None,
    dry_run=False,
    allow_dirty=False,
    parse=DEFAULT_PARSE_REGEX,
    serialize=DEFAULT_SERIALIZE,
):
    ctx.run("git fetch --force --tags")

    current_branch = get_branch(ctx)
    if current_branch != "master":
        # raise ValueError("You are on branch %s, but you must be on branch master to release")
        pass
    if version is None:
        current_version = get_project_version(ctx, component=component)

        if current_version is None:
            current_version = component + "/0.0.1" if component else "0.0.1"
        new_version = _bump_version(
            ctx,
            parse=parse,
            serialize=serialize,
            current_version=current_version,
            mode=mode,
            dry_run=dry_run,
            allow_dirty=allow_dirty,
        )
    else:
        new_version = _create_new_version(
            ctx,
            parse=parse,
            serialize=serialize,
            version=component + "/" + version if component else version,
            dry_run=dry_run,
            allow_dirty=allow_dirty,
        )

    tag = new_version.replace("new_version=", "")
    if not dry_run:
        ctx.run("git push origin " + tag)
        print("Created tag " + tag)
    else:
        print("DRY RUN: Would have created tag " + tag)


def get_branch(ctx):
    cmd = "git symbolic-ref -q --short HEAD"
    result = ctx.run(cmd, hide=True, warn=True)
    if result.ok:
        return result.stdout.splitlines()[-1]
    else:
        raise ValueError("Failed to retrieve branch name from git command")


def check_project_change_on_commit_range(ctx, path, commit_range):
    """
    Check whether a specific path has changed in a specific commit-range
    """
    with ctx.cd(get_project_root(ctx)):
        ctx.run(
            "git diff --name-only {commit_range} | sort -u | uniq | grep {path} > /dev/null".format(
                path=path, commit_range=commit_range
            )
        )


def check_project_tag_match(ctx, component, tag):
    """
    Check whether a specific tag matches a path
    """
    return tag.startswith(component + "/")