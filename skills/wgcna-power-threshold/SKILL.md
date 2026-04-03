---
name: wgcna-power-threshold
description: Given a dataset name, find its expression matrix on the VEuPathDB workflow server, rsync it locally, and determine the WGCNA soft-threshold power.
argument-hint: <dataset-name>
allowed-tools: Bash
---

!`cat ${CLAUDE_SKILL_DIR}/../../shared/sync-dataset-steps.md`

Substitute every occurrence of `DATASET_NAME` above with: **$ARGUMENTS**

After completing the steps above you have `remotePath` — the full path to the dataset directory on yew. Continue:

---

## Step 4 — Determine data type from the remote path

Inspect `remotePath` for "rnaseq" or "microarray" (case-insensitive).

- If it contains **rnaseq** → proceed to Step 5.
- If it contains **microarray** → skip to Step 6.
- If neither is clear, stop and ask the user to clarify the data type.

---

## Step 5 — RNAseq: find the expression matrix

Search for WGCNA input files under `remotePath`:

```bash
ssh yew "find <remotePath> -type f -name 'wgcnaInput*.txt'"
```

**Case A — only `wgcnaInput_unstranded.txt` found:**
Capture its full path as `remoteInputFile`. Skip to Step 7.

**Case B — both `wgcnaInput_firststrand.txt` and `wgcnaInput_secondstrand.txt` found:**
Rsync both files locally to decide which is sense:

```bash
mkdir -p /tmp/$ARGUMENTS
rsync -aL yew:<path/to/wgcnaInput_firststrand.txt> /tmp/$ARGUMENTS/
rsync -aL yew:<path/to/wgcnaInput_secondstrand.txt> /tmp/$ARGUMENTS/
```

Run R to compare column means:

```bash
Rscript - <<'EOF'
first  <- read.table("/tmp/$ARGUMENTS/wgcnaInput_firststrand.txt",  header=TRUE, row.names=1, sep="\t", check.names=FALSE)
second <- read.table("/tmp/$ARGUMENTS/wgcnaInput_secondstrand.txt", header=TRUE, row.names=1, sep="\t", check.names=FALSE)
first_mean  <- mean(colMeans(first,  na.rm=TRUE))
second_mean <- mean(colMeans(second, na.rm=TRUE))
cat("First strand mean: ",  first_mean,  "\n")
cat("Second strand mean: ", second_mean, "\n")
ratio <- max(first_mean, second_mean) / min(first_mean, second_mean)
cat("Ratio: ", ratio, "\n")
if (ratio < 2) {
  cat("AMBIGUOUS: means are too similar to determine sense strand.\n")
} else if (first_mean > second_mean) {
  cat("SELECTED: firststrand\n")
} else {
  cat("SELECTED: secondstrand\n")
}
EOF
```

- If output is `AMBIGUOUS`, stop and tell the user the strand could not be determined (report both means).
- Otherwise set `remoteInputFile` to the remote path of the selected strand file. Skip to Step 7.

**Case C — no `wgcnaInput*.txt` files found:**
Stop and tell the user no WGCNA input files were found under `remotePath`.

---

## Step 6 — Microarray: find the expression matrix

```bash
ssh yew "find <remotePath> -type f -name 'profiles.txt'"
```

If exactly one file is found, capture it as `remoteInputFile`. Continue to Step 7.  
If zero files are found, stop and tell the user no `profiles.txt` was found — list all `.txt` files under `remotePath` and ask the user to pick one.  
If more than one is found, show the list and ask the user to pick one.

---

## Step 7 — Locate analysisConfig.xml via manual delivery path

!`cat ${CLAUDE_SKILL_DIR}/../../shared/manual-delivery-path.md`

Substitute every occurrence of `DATASET_NAME` above with: **$ARGUMENTS**

`technologyType` was determined in Step 4 (`RNASeq` or `Microarray`).

After completing the steps above you have `manualDeliveryPath`. The `analysisConfig.xml` lives at:

```
<manualDeliveryPath>/analysisConfig.xml
```

Rsync it along with the chosen input file:

```bash
mkdir -p /tmp/$ARGUMENTS
rsync -aL yew:<remoteInputFile> /tmp/$ARGUMENTS/
rsync -aL yew:<manualDeliveryPath>/analysisConfig.xml /tmp/$ARGUMENTS/
```

If `analysisConfig.xml` is not found on the remote (rsync exits non-zero or the file is absent), stop and tell the user it was not found at `<manualDeliveryPath>/analysisConfig.xml`.

Write a `paths.txt` file recording the key remote paths found during this run:

```bash
cat > /tmp/$ARGUMENTS/paths.txt <<EOF
datasetName:         $ARGUMENTS
remoteInputFile:     <remoteInputFile>
manualDeliveryPath:  <manualDeliveryPath>
analysisConfig:      <manualDeliveryPath>/analysisConfig.xml
EOF
```

---

## Step 8 — Determine WGCNA soft-threshold power and save plot

```bash
Rscript - <<'EOF'
library(WGCNA)
options(stringsAsFactors = FALSE)

input_file <- list.files("/tmp/$ARGUMENTS", pattern = "wgcnaInput.*\\.txt|profiles\\.txt", full.names = TRUE)[1]
cat("Using input file:", input_file, "\n")

data <- read.table(input_file, header=TRUE, row.names=1, sep="\t", check.names=FALSE)
# samples as rows, genes as columns
expr <- t(data)

powers <- c(1:30)
sft <- pickSoftThreshold(expr, powerVector = powers, verbose = 5)

cat("\nRecommended soft-threshold power:", sft$powerEstimate, "\n")
if (is.na(sft$powerEstimate)) {
  cat("\nScale-free topology fit table:\n")
  print(sft$fitIndices)
}

# Save power-threshold selection plot
pdf("/tmp/$ARGUMENTS/power_threshold_plot.pdf", width = 9, height = 5)
par(mfrow = c(1, 2))
plot(sft$fitIndices[, 1],
     -sign(sft$fitIndices[, 3]) * sft$fitIndices[, 2],
     xlab = "Soft Threshold (power)",
     ylab = "Scale Free Topology Model Fit, signed R\u00b2",
     type = "n", main = "Scale independence")
text(sft$fitIndices[, 1],
     -sign(sft$fitIndices[, 3]) * sft$fitIndices[, 2],
     labels = powers, col = "red")
abline(h = 0.85, col = "red", lty = 2)
plot(sft$fitIndices[, 1], sft$fitIndices[, 5],
     xlab = "Soft Threshold (power)",
     ylab = "Mean Connectivity",
     type = "n", main = "Mean connectivity")
text(sft$fitIndices[, 1], sft$fitIndices[, 5],
     labels = powers, col = "red")
dev.off()
cat("Plot saved to /tmp/$ARGUMENTS/power_threshold_plot.pdf\n")
EOF
```

Capture the recommended power as `softThresholdPower`. If it is `NA`, stop and tell the user no clear threshold was found and show the fit table.

---

## Step 9 — Write per-dataset output directory

By this point you have captured:
- `datasetName` = `$ARGUMENTS`
- `softThresholdPower` from Step 8
- `organismAbbrev` from Step 2
- `inputFileBasename` = basename of `remoteInputFile`
- `strandType` = one of: `firststrand`, `secondstrand`, `unstranded`, or `microarray`
- `technologyType` = `RNASeq` (Steps 5) or `Microarray` (Step 6)

Derive `inputSuffixMM`:
- RNASeq: `[module - membership - <strandType> - tpm - unique]`
- Microarray: `[module - membership - microarray]`

Create the dataset output directory, copy the rsynced `analysisConfig.xml` and the plot into it, then insert the `<step>` block as a new child element immediately before the last closing tag in `analysisConfig.xml`:

```bash
mkdir -p ~/wgcna/$ARGUMENTS
cp /tmp/$ARGUMENTS/analysisConfig.xml ~/wgcna/$ARGUMENTS/analysisConfig.xml
cp /tmp/$ARGUMENTS/power_threshold_plot.pdf ~/wgcna/$ARGUMENTS/
cp /tmp/$ARGUMENTS/paths.txt ~/wgcna/$ARGUMENTS/paths.txt
```

```bash
python3 - <<'PYEOF'
import os

path = os.path.expanduser("~/wgcna/$ARGUMENTS/analysisConfig.xml")
with open(path) as f:
    content = f.read()

step_xml = """
<!-- datasetName: $ARGUMENTS | project: <projectName> | organism: <organismAbbrev> | softThresholdPower: <softThresholdPower> -->
<step class="ApiCommonData::Load::IterativeWGCNAResults">
  <property name="profileSetName" value="WGCNA $ARGUMENTS" />
  <property name="inputFile" value="<inputFileBasename>" />
  <property name="softThresholdPower" value="<softThresholdPower>" />
  <property name="organismAbbrev" value="<organismAbbrev>" />
  <property name="inputSuffixMM" value="<inputSuffixMM>" />
  <property name="technologyType" value="<technologyType>" />
  <property name="threshold" value="1" />
  <property name="samples" isReference="1" value="$globalReferencable->{samples}" />
</step>
"""

last_close = content.rfind('</')
if last_close == -1:
    content = content + step_xml
else:
    content = content[:last_close] + step_xml + content[last_close:]

with open(path, 'w') as f:
    f.write(content)

print("Step inserted into", path)
PYEOF
```

Report the output directory (`~/wgcna/$ARGUMENTS/`) and its contents to the user:
- `analysisConfig.xml` — rsynced file with the step XML inserted
- `power_threshold_plot.pdf` — scale-free topology plot used to choose the power threshold
- `paths.txt` — remote paths found during this run (input file and analysisConfig)
