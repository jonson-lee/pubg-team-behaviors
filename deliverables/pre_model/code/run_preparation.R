#!/usr/bin/env Rscript
# Data preparation only / 仅准备数据，不拟合模型。
# Raw inputs stay read-only; three generated processed files are replaced.
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
if (length(script_arg) != 1L) stop("Run this entry point using Rscript.")
script_path <- normalizePath(gsub("~+~", " ", sub("^--file=", "", script_arg),
                                fixed = TRUE))
project_dir <- dirname(dirname(script_path))
if (length(commandArgs(trailingOnly = TRUE))) {
  stop("This entry point accepts no arguments. Usage: Rscript run_preparation.R")
}
source(file.path(project_dir, "code", "prepare_data.R"))

message("Preparing the fixed 200-match solo-fpp sample...")
prepared <- prepare_data(project_dir)
matches <- prepared$matches
n_train <- sum(matches$split == "train")
n_test <- sum(matches$split == "test")
stopifnot(nrow(matches) == 200L, n_train == 160L, n_test == 40L,
          nrow(prepared$data) == prepared$audit$sampling$records)

cat(sprintf("Prepared %d records from %d solo-fpp matches.\n",
            nrow(prepared$data), nrow(matches)))
cat(sprintf("Whole-match split: %d training / %d held-out matches (%d / %d records).\n",
            n_train, n_test, sum(prepared$data$split == "train"),
            sum(prepared$data$split == "test")))
cat("Saved data/processed/pubg_sample.csv, selected_matches.csv and data_audit.json.\n")
