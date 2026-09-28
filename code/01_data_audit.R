# ---------------------------------------------------------------------------
# 01_data_audit.R -- milestone M1: filter, aggregate to teams, audit.
# Run from the repository root: Rscript code/01_data_audit.R
# Method reference: docs/ANALYSIS_PLAN_R.md sections 2 and 4.
# ---------------------------------------------------------------------------

source(file.path("code", "R", "io.R"))
source(file.path("code", "R", "audit.R"))

ensure_dir(PROCESSED_DIR)
ensure_dir(REPORTS_DIR)

message("Reading PUBG training data (selected columns) ...")
players <- read_pubg(RAW_FILES$train)
players <- filter_modes(players)
message(sprintf("Retained %s player rows across study modes.",
                format(nrow(players), big.mark = ",")))

message("Aggregating player rows to teams (matchId + groupId) ...")
teams <- aggregate_teams(players)

data.table::fwrite(teams, file.path(PROCESSED_DIR, "teams_all_modes.csv"))

primary <- teams[matchType == PRIMARY_MODE]
data.table::fwrite(primary, file.path(PROCESSED_DIR, "teams_squad_fpp.csv"))
message(sprintf("Primary sample (%s): %s team-match records.",
                PRIMARY_MODE, format(nrow(primary), big.mark = ",")))

findings <- audit_checks(players, teams)
report_path <- file.path(REPORTS_DIR, "data_audit.md")
write_audit_report(findings, players, teams, report_path)
message("Audit report written to ", report_path)

print(mode_summary(players, teams))

# TODO(M1): save a data dictionary for every retained feature and exclusion.
# TODO(M1): record source-card sha256 checksums of the raw files in the report.
