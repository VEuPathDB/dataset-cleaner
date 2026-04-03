---
name: find-dataset-in-workflow
description: Given a dataset name, look up and return its full path on the VEuPathDB workflow fileserver.
argument-hint: <dataset-name>
allowed-tools: Bash
---

!`cat ${CLAUDE_SKILL_DIR}/../../shared/sync-dataset-steps.md`

Substitute every occurrence of `DATASET_NAME` above with: **$ARGUMENTS**
