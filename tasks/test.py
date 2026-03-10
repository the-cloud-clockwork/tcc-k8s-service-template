import os
from invoke import task
from . import helpers


@task
def chart(ctx,):
    """
    Examine the k8s-service-template helm chart for possible issues
    """
    with ctx.cd(os.path.join(helpers.get_project_root(ctx))):
        ctx.run(
            f"""
                helm lint .
            """
        )