# ---------------------------------------------------------------------------
# config.R -- shared configuration for the IBA6101 PUBG analysis.
# Sourced by every script. Holds paths, column groups and filter settings only.
# Method rationale: docs/ANALYSIS_PLAN_R.md
# ---------------------------------------------------------------------------

# --- Paths -----------------------------------------------------------------
# Scripts are run from the project root, e.g. `Rscript code/01_data_audit.R`.
RAW_DIR       <- file.path("data", "raw", "pubg")
PROCESSED_DIR <- file.path("data", "processed")
REPORTS_DIR   <- file.path("reports")

RAW_FILES <- list(
  train = file.path(RAW_DIR, "train_V2.csv"),
  test  = file.path(RAW_DIR, "test_V2.csv")
)

# --- Columns ---------------------------------------------------------------
ID_COLS    <- c("Id", "groupId", "matchId")
OUTCOME    <- "winPlacePerc"

CONTEXT_COLS <- c("maxPlace", "numGroups")

# Post-match / outcome-proximal / rating fields: excluded from the behaviour model.
EXCLUDED_COLS <- c("killPlace", "matchDuration", "rankPoints", "winPoints",
                   "killPoints", "Id", "groupId", "matchId")

# --- Behaviour blocks (pre-specified, see docs/PROJECT_CONTEXT.md) ---------
# NOTE: each variable belongs to exactly one block. The assists/DBNOs/revives
# assignment is provisional and frozen at milestone M2 (feature freeze).
COMBAT_COLS <- c("kills", "damageDealt", "headshotKills", "killStreaks",
                 "longestKill", "roadKills", "teamKills", "vehicleDestroys")

MOBILITY_COLS <- c("walkDistance", "rideDistance", "swimDistance",
                   "heals", "boosts", "weaponsAcquired")

COORDINATION_COLS <- c("assists", "DBNOs", "revives")

BEHAVIOUR_COLS <- c(COMBAT_COLS, MOBILITY_COLS, COORDINATION_COLS)

# --- Samples ---------------------------------------------------------------
PRIMARY_MODE        <- "squad-fpp"
SUPPLEMENTARY_MODES <- c("duo-fpp", "solo-fpp")
STUDY_MODES         <- c(PRIMARY_MODE, SUPPLEMENTARY_MODES)

# Mode -> expected players per team, used by the team-size audit.
EXPECTED_TEAM_SIZE <- c("squad-fpp" = 4L, "duo-fpp" = 2L, "solo-fpp" = 1L)

# --- Helpers ---------------------------------------------------------------
ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE)
  invisible(path)
}

analysis_columns <- function() {
  unique(c(ID_COLS, CONTEXT_COLS, "matchType", OUTCOME, BEHAVIOUR_COLS))
}
