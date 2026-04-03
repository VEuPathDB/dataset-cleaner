#!/usr/bin/env Rscript
# Usage: Rscript wgcna-power-threshold.R <dataset_name>
# Reads the expression matrix from /tmp/<dataset_name>/, runs WGCNA
# pickSoftThreshold, prints the recommended power, and saves a plot to
# /tmp/<dataset_name>/power_threshold_plot.pdf.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1) {
  stop("Usage: wgcna-power-threshold.R <dataset_name>")
}

dataset <- args[1]
base_dir <- file.path("/tmp", dataset)

library(WGCNA)
options(stringsAsFactors = FALSE)

input_file <- list.files(base_dir, pattern = "wgcnaInput.*\\.txt|profiles\\.txt", full.names = TRUE)[1]
cat("Using input file:", input_file, "\n")

data <- read.table(input_file, header=TRUE, row.names=1, sep="\t", check.names=FALSE)
expr <- t(data)

powers <- c(1:30)
sft <- pickSoftThreshold(expr, powerVector = powers, verbose = 5)

cat("\nRecommended soft-threshold power:", sft$powerEstimate, "\n")
if (is.na(sft$powerEstimate)) {
  cat("\nScale-free topology fit table:\n")
  print(sft$fitIndices)
}

plot_path <- file.path(base_dir, "power_threshold_plot.pdf")
pdf(plot_path, width = 9, height = 5)
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
cat("Plot saved to", plot_path, "\n")
