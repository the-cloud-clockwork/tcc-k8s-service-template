from invoke import task
from .build import k8s_service_template as build_k8s_service_template
from .publish import k8s_service_template as publish_k8s_service_template


@task
def k8s_service_template(ctx, dev=False, version=None, username=None, password=None):
    """
    Build and publish a new version of the k8s-service-template helm chart
    """
    chart_file = build_k8s_service_template(ctx, version=version)
    publish_k8s_service_template(ctx, chart_file=chart_file, dev=dev, username=username, password=password)