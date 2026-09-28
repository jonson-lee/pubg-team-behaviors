# ---------------------------------------------------------------------------
# 00_setup.R -- install and load the packages required by the pipeline.
# Run once from the repository root: Rscript code/00_setup.R
# ---------------------------------------------------------------------------

required_packages <- c(
  "data.table", "dplyr", "ggplot2", "moments", "corrplot",
  "car", "lmtest", "sandwich", "boot", "broom", "modelsummary"
)

missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages) > 0L) {
  message("Installing missing packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages)
}

for (pkg in required_packages) {
  suppressPackageStartupMessages(
    library(pkg, character.only = TRUE, quietly = TRUE)
  )
}

message("R environment ready: ", paste(required_packages, collapse = ", "))
