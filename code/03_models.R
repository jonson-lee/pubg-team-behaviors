# ---------------------------------------------------------------------------
# 03_models.R -- milestones M3/M4: nested regression models and validation.
# Run from the repository root (after the M2 feature freeze): Rscript code/03_models.R
# Method reference: docs/ANALYSIS_PLAN_R.md sections 7 and 9.
#
# DRAFT: this is a starting skeleton. Do not finalise transformations or the
# model order until milestone M2 (feature freeze) is recorded.
# ---------------------------------------------------------------------------

source(file.path("code", "R", "io.R"))

ensure_dir(REPORTS_DIR)

teams_path <- file.path(PROCESSED_DIR, "teams_squad_fpp.csv")
if (!file.exists(teams_path)) {
  stop("Run code/01_data_audit.R first to create ", teams_path, call. = FALSE)
}
teams <- data.table::fread(teams_path)

analysis <- teams[!is.na(winPlacePerc)]

# --- Nested linear models (pre-specified order) ----------------------------
m_context      <- stats::lm(reformulate(CONTEXT_COLS, response = OUTCOME), data = analysis)
m_combat       <- stats::update(m_context, reformulate(c(CONTEXT_COLS, COMBAT_COLS), response = OUTCOME))
m_mobility     <- stats::update(m_combat, reformulate(c(CONTEXT_COLS, COMBAT_COLS, MOBILITY_COLS), response = OUTCOME))
m_coordination <- stats::update(m_mobility, reformulate(c(CONTEXT_COLS, COMBAT_COLS, MOBILITY_COLS, COORDINATION_COLS), response = OUTCOME))

block_tests <- stats::anova(m_context, m_combat, m_mobility, m_coordination)
print(block_tests)

if (requireNamespace("broom", quietly = TRUE)) {
  coefs <- broom::tidy(m_coordination)
  data.table::fwrite(coefs, file.path(REPORTS_DIR, "models_coefficients.csv"))
}

# TODO(M3): cluster-robust standard errors by matchId
#           (sandwich::vcovCL + lmtest::coeftest, or fixest::feols(cluster = ~matchId)).
# TODO(M3): residual diagnostics (residual/fitted, QQ, VIF, BP test, Cook's D).
# TODO(M4): complete-match holdout; matchId-level bootstrap for stability;
#           RMSE/MAE/R2 versus the training-mean baseline (5% improvement gate).
# TODO(M4): Top-10% logistic check; duo-fpp / solo-fpp robustness.

message("Draft modelling script finished. See docs/ANALYSIS_PLAN_R.md for the full plan.")
