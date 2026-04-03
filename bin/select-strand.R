#!/usr/bin/env Rscript
# Usage: Rscript select-strand.R <dataset_name>
# Compares column means of firststrand vs secondstrand WGCNA input files
# located at /tmp/<dataset_name>/. Prints SELECTED: <strand> or AMBIGUOUS.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: select-strand.R <dataset_name>")
}

dataset <- args[1]
base_dir <- file.path("/tmp", dataset)

first_path  <- file.path(base_dir, "wgcnaInput_firststrand.txt")
second_path <- file.path(base_dir, "wgcnaInput_secondstrand.txt")

first  <- read.table(first_path,  header=TRUE, row.names=1, sep="\t", check.names=FALSE)
second <- read.table(second_path, header=TRUE, row.names=1, sep="\t", check.names=FALSE)

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
