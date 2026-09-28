# ---------------------------------------------------------------------------
# io.R -- reading and filtering helpers.
# ---------------------------------------------------------------------------

source(file.path("code", "R", "config.R"))

#' Read selected columns from a PUBG raw CSV.
#' Raw files are read-only; only the requested columns are loaded.
read_pubg <- function(path, columns = analysis_columns()) {
  if (!file.exists(path)) {
    stop("Missing raw file: ", path,
         "\nDownload the Kaggle data into ", RAW_DIR, " (see data/meta/pubg_source.md).",
         call. = FALSE)
  }
  if (!requireNamespace("data.table", quietly = TRUE)) {
    stop("Package 'data.table' is required. Run code/00_setup.R first.", call. = FALSE)
  }

  header <- names(data.table::fread(path, nrows = 0L, showProgress = FALSE))
  wanted <- intersect(columns, header)
  missing <- setdiff(columns, header)
  if (length(missing) > 0L) {
    warning("Columns not found and skipped: ", paste(missing, collapse = ", "))
  }

  data.table::fread(
    path,
    select       = wanted,
    na.strings   = c("", "NA"),
    showProgress = TRUE
  )
}

#' Keep only the study modes (primary + supplementary).
filter_modes <- function(dt, modes = STUDY_MODES) {
  stopifnot(data.table::is.data.table(dt))
  dt[matchType %in% modes]
}
