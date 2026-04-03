# Get Manual Delivery Path

Use these steps to construct the manual delivery base path for **DATASET_NAME**.

The caller must supply `technologyType` as either `RNASeq` or `Microarray` before including these steps.

## Step MD-1 — Look up project and organism abbreviation

```bash
psql -c "
SELECT dd.project_id, o.abbrev
FROM   apidbtuning.datasetpresenter  dp
JOIN   apidbtuning.datasetdatasource dd USING (dataset_presenter_id)
JOIN   apidb.organism o USING (taxon_id)
WHERE  dd.name = 'DATASET_NAME';
"
```

If 0 rows are returned, stop and tell the user the dataset was not found.  
If more than 1 distinct `(project_id, abbrev)` pair is returned, show the results and ask the user to clarify.

Capture `projectName` (from `project_id`) and `organismAbbrev` (from `abbrev`).

## Step MD-2 — Query dataset version

```bash
psql -c "SELECT version FROM apidb.datasource WHERE name = 'DATASET_NAME';"
```

If 0 rows are returned, stop and tell the user no datasource was found with that name.

Capture the result as `datasetVersion`.

## Step MD-3 — Find the correct dataset directory under manual delivery

Map `technologyType` to its subdirectory:

| technologyType | subdirectory            |
|----------------|-------------------------|
| RNASeq         | `rnaSeq`                |
| Microarray     | `microarrayExpression`  |

The technology root is:

```
/eupath/data/EuPathDB/manualDelivery/<projectName>/<organismAbbrev>/<subdirectory>/
```

> **Note:** The directory name under the technology root will **not** match `DATASET_NAME` exactly.
> - The organism abbreviation prefix (e.g. `pfal3D7_`) is stripped from the directory name.
> - Common suffixes like `_RNASeq_RSRC` or `_Microarray_RSRC` are also absent.
> - For example, dataset `pfal3D7_Lee_Gambian_RNASeq_RSRC` maps to directory `Lee_Gambian`.

List the available directories on the remote server:

```bash
ssh yew "ls /eupath/data/EuPathDB/manualDelivery/<projectName>/<organismAbbrev>/<subdirectory>/"
```

Identify the directory whose name is a substring of `DATASET_NAME` (after stripping the organism prefix and any `_RNASeq_RSRC` / `_Microarray_RSRC` / `_RSRC` suffix). If the match is ambiguous, show the list and ask the user to pick.

Capture the matched name as `deliveryDirName`.

## Step MD-4 — Confirm the versioned final path

Construct the candidate path and verify the `final` directory exists:

```bash
ssh yew "ls /eupath/data/EuPathDB/manualDelivery/<projectName>/<organismAbbrev>/<subdirectory>/<deliveryDirName>/<datasetVersion>/final"
```

If the path does not exist, list what versions are present and ask the user to confirm:

```bash
ssh yew "ls /eupath/data/EuPathDB/manualDelivery/<projectName>/<organismAbbrev>/<subdirectory>/<deliveryDirName>/"
```

Once confirmed, capture `manualDeliveryPath`:

```
/eupath/data/EuPathDB/manualDelivery/<projectName>/<organismAbbrev>/<subdirectory>/<deliveryDirName>/<datasetVersion>/final
```
