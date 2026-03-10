# = k8s-service-template Tasks
#
# Powered by Python Invoke
#
# Doc:
# - http://docs.pyinvoke.org/en/latest/index.html
#
from invoke import Collection


# Local modules split tasks
from . import build, publish, deploy, test


# == Create & Configure the top level namespace
#
ns = Collection()

ns.configure({"tasks": {"auto_dash_names": True}, "run": {"echo": True, "pty": True}})

# == Register namespaces modules
#

ns.add_collection(build)
ns.add_collection(publish)
ns.add_collection(deploy)
ns.add_collection(test)