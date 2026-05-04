import os

from invoke import task

from . import helpers


def build_chart(
    ctx,
    chart_dir,
    version=None
):
    """
    Package a helm chart
    """
    chart_version = version if version is not None else helpers.get_project_version(ctx)
    # Strip 'v' prefix if present (git tags often have 'v' but helm expects semantic version)
    if chart_version and chart_version.startswith('v'):
        chart_version = chart_version[1:]
    with ctx.cd(os.path.join(helpers.get_project_root(ctx))):
        ctx.run(
            f"""
                helm package {chart_dir} \
                --version {chart_version}
            """
        )
    # Handle the case where chart_dir is "." - use the actual chart name
    if chart_dir == ".":
        chart_name = "tcc-k8s-service-template"
    else:
        chart_name = chart_dir.split("/")[-1]
    chart_file = chart_name + "-" + chart_version + ".tgz"
    return chart_file


@task(help=dict(version="The version to use to package the chart"))
def k8s_service_template(ctx, version=None):
    """
    Build k8s-service-template helm chart
    """
    return build_chart(ctx, ".", version=version)