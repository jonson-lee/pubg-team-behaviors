# ---------------------------------------------------------------------------
# 02_eda.R -- milestone M2: descriptive statistics, figures, feature freeze.
# Run from the repository root: Rscript code/02_eda.R
# Method reference: docs/ANALYSIS_PLAN_R.md sections 3, 5 and 6.
# ---------------------------------------------------------------------------

source(file.path("code", "R", "io.R"))

ensure_dir(REPORTS_DIR)

teams_path <- file.path(PROCESSED_DIR, "teams_squad_fpp.csv")
if (!file.exists(teams_path)) {
  stop("Run code/01_data_audit.R first to create ", teams_path, call. = FALSE)
}
teams <- data.table::fread(teams_path)

# --- Descriptive table -----------------------------------------------------
desc_cols <- intersect(c(OUTCOME, BEHAVIOUR_COLS, CONTEXT_COLS), names(teams))

descriptives <- data.table::rbindlist(lapply(desc_cols, function(v) {
  x <- teams[[v]]
  data.table::data.table(
    variable = v,
    n        = sum(!is.na(x)),
    mean     = mean(x, na.rm = TRUE),
    sd       = stats::sd(x, na.rm = TRUE),
    median   = stats::median(x, na.rm = TRUE),
    q1       = as.numeric(stats::quantile(x, 0.25, na.rm = TRUE)),
    q3       = as.numeric(stats::quantile(x, 0.75, na.rm = TRUE)),
    min      = min(x, na.rm = TRUE),
    max      = max(x, na.rm = TRUE),
    missing  = sum(is.na(x))
  )
}))
data.table::fwrite(descriptives, file.path(REPORTS_DIR, "eda_descriptives.csv"))

# --- Correlations among behaviour variables --------------------------------
behaviour <- intersect(BEHAVIOUR_COLS, names(teams))
cors <- stats::cor(as.matrix(teams[, ..behaviour]), use = "pairwise.complete.obs")
data.table::fwrite(as.data.frame(cors), file.path(REPORTS_DIR, "eda_correlations.csv"))

# --- Outcome distribution figure -------------------------------------------
if (requireNamespace("ggplot2", quietly = TRUE)) {
  p <- ggplot2::ggplot(teams, ggplot2::aes(x = winPlacePerc)) +
    ggplot2::geom_histogram(bins = 50, fill = "#4C72B0", colour = "white") +
    ggplot2::labs(x = "winPlacePerc", y = "teams",
                  title = "Team final placement percentile (squad-fpp)") +
    ggplot2::theme_minimal()
  ggplot2::ggsave(file.path(REPORTS_DIR, "fig_winplaceperc_hist.png"),
                  p, width = 7, height = 4, dpi = 150)
}

message("EDA outputs written to ", REPORTS_DIR)

# TODO(M2): skewness/zero-inflation checks, outlier review (1.5x IQR),
#           collinearity (VIF), cross-mode comparison, and the frozen feature
#           list + nested-model order recorded in docs/ANALYSIS_PLAN_R.md.
