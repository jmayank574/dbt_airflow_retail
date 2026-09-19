from airflow.sdk import dag, task
import pendulum


@dag(
        dag_id="orchestrate",
        schedule= "0 11 * * *",
        catchup=False,
        start_date=pendulum.datetime(2024, 9, 19, tz="UTC")
)
def orchestrate():
    @task
    def ingest_cdc():
        from databricks.sdk import WorkspaceClient
        from databricks.sdk.service.jobs import RunLifeCycleState, RunResultState
        import time

        # Reads DATABRICKS_HOST / DATABRICKS_TOKEN from the environment
        # (see airflow/.env, gitignored) - never hardcode credentials here.
        ws = WorkspaceClient()

        job_trigger = ws.jobs.run_now(job_id=121344543707903)

        while True:
            job_status = ws.jobs.get_run(run_id=job_trigger.run_id)
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

    @task.bash
    def source_freshness():
        return "cd /opt/airflow/dbt_project && dbt source freshness"

    @task.bash
    def silver_technical():
        return "cd /opt/airflow/dbt_project && dbt run --select silver_t"

    @task.bash
    def silver_technical_test():
        return "cd /opt/airflow/dbt_project && dbt test --select silver_t"

    @task.bash
    def silver_business():
        return "cd /opt/airflow/dbt_project && dbt run --select silver_b"

    @task.bash
    def silver_business_test():
        return "cd /opt/airflow/dbt_project && dbt test --select silver_b"

    @task.bash
    def gold_ephemeral():
        return "cd /opt/airflow/dbt_project && dbt run --select gold/ephemeral"

    @task.bash
    def gold_dimension():
        return "cd /opt/airflow/dbt_project && dbt snapshot"

    @task.bash
    def gold_fact():
        return "cd /opt/airflow/dbt_project && dbt run --select gold/fact"

    @task.bash
    def gold_fact_test():
        return "cd /opt/airflow/dbt_project && dbt test --select gold/fact"

    
    


    ingest_cdc() >> source_freshness() >> silver_technical() >> silver_technical_test() >> silver_business() >> silver_business_test() >> gold_ephemeral() >> gold_dimension() >> gold_fact() >> gold_fact_test()

orchestrate_dag = orchestrate()