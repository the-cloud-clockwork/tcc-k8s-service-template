from invoke import task

from . import helpers
from .helm import CHART_REPO, DEV_CHART_REPO


def publish_chart(ctx, packaged_chart_file, dev=False):
    with ctx.cd(helpers.get_project_root(ctx)):
        repo = DEV_CHART_REPO if dev else CHART_REPO
        ctx.run(f"helm push {packaged_chart_file} {repo}")


@task
def k8s_service_template(ctx, chart_file=None, version=None, dev=False):
    """
    Push k8s-service-template helm chart to GHCR
    """
    if chart_file is not None:
        packaged_chart_file = chart_file
    else:
        chart_version = version if version is not None else helpers.get_project_version(ctx)
        packaged_chart_file = "tcc-k8s-service-template-" + chart_version + ".tgz"

    publish_chart(ctx, packaged_chart_file, dev=dev)
