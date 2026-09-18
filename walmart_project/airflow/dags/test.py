from databricks.sdk import WorkspaceClient
from databricks.sdk.service.jobs import RunLifeCycleState, RunResultState
import time

# Reads DATABRICKS_HOST / DATABRICKS_TOKEN from the environment - never
# hardcode credentials here. Set them in your shell before running locally:
#   $env:DATABRICKS_HOST = "dbc-71a360b8-ebdc.cloud.databricks.com"
#   $env:DATABRICKS_TOKEN = "<token from walmart_project/profiles.yml>"
ws=WorkspaceClient()

job_trigger=ws.jobs.run_now(job_id=121344543707903)

while True:
    job_status=ws.jobs.get_run(run_id=job_trigger.run_id)
    if job_status.state.life_cycle_state in [
        RunLifeCycleState.TERMINATED,
        RunLifeCycleState.SKIPPED,
        RunLifeCycleState.INTERNAL_ERROR,
    ]:
       if job_status.state.result_state == RunResultState.SUCCESS:
          print("Job completed successfully")
          break
       else:
          raise Exception(f"Job failed with state: {job_status.state.result_state}")

    time.sleep(5)