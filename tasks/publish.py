from invoke import task

from . import helpers
from .helm import CHART_REPO, DEV_CHART_REPO


def publish_chart(ctx, packaged_chart_file, dev=False, username=None, password=None):
    with ctx.cd(helpers.get_project_root(ctx)):
        ctx.run(
            f"""
                helm push-artifactory \
                --path data \
                {"-u " + username + " -p " + password if username is not None and password is not None else ""} \
                {packaged_chart_file} \
                {DEV_CHART_REPO if dev else CHART_REPO} \
                --skip-reindex
            """
        )


@task
def k8s_service_template(ctx, chart_file=None, version=None, dev=False, username=None, password=None):
    """
    Push k8s-service-template helm chart to the artifactory
    """
    if chart_file is not None:
        packaged_chart_file = chart_file
    else:
        chart_version = version if version is not None else helpers.get_project_version(ctx)
        packaged_chart_file = "k8s-service-template-" + chart_version + ".tgz"

    publish_chart(ctx, packaged_chart_file, dev=dev, username=username, password=password)