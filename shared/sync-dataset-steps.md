# Find Dataset in Workflow Steps

Use these steps to find a VEuPathDB dataset named **DATASET_NAME** on the remote workflow server. Replace `DATASET_NAME` with the actual dataset name.

## Step 1 — Verify a single workflow exists

```bash
psql -c "SELECT name, version FROM apidb.workflow;"
```

If the result is not exactly **1 row**, stop and tell the user: "Expected 1 row in apidb.workflow but got N. Cannot determine workflow path."

Capture `workflowName` and `workflowVersion` from that row.

## Step 2 — Look up project and organism abbreviation

```bash
psql -c "
SELECT dd.project_id, o.abbrev
FROM   apidbtuning.datasetpresenter  dp
JOIN   apidbtuning.datasetdatasource dd USING (dataset_presenter_id)
JOIN   apidb.organism o USING (taxon_id)
WHERE  dd.name = 'DATASET_NAME';
"
```

If **0 rows** are returned, stop and tell the user the dataset was not found.  
If **more than 1 distinct (project_id, abbrev) pair** is returned, show the user the results and ask them to clarify.

Capture `projectName` (from `project_id`) and `organismAbbrev` (from `abbrev`).

## Step 3 — Find the dataset directory on the remote server

Construct the search root from what you know:

```
/veupath/data/workflows/<workflowName>/<workflowVersion>/data/<projectName>/<organismAbbrev>
```

Run a find over ssh to locate the dataset directory by name:

```bash
ssh yew "find /veupath/data/workflows/<workflowName>/<workflowVersion>/data/<projectName>/<organismAbbrev> -maxdepth 3 -type d -name 'DATASET_NAME'"
```

If **0 results**, stop and tell the user the directory was not found on the remote server.  
If **more than 1 result**, show the user the list and ask them to pick one.

Report the full remote path to the user.
