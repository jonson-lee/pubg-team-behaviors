# Reproducible match-level sampling of the PUBG training data.
# Source this file, then call prepare_data(<path to Project>).

validate_sample_mode <- function(data) {
  if (!is.data.frame(data) || !"matchType" %in% names(data) ||
      anyNA(data$matchType) || any(data$matchType != "solo-fpp")) {
    stop("Sample mode contract violation: matchType must be present, non-missing and entirely solo-fpp.",
         call. = FALSE)
  }
  invisible(NULL)
}

prepare_data <- function(project_dir, sample_size = 200L,
                         sample_seed = 6101L, split_seed = 6102L,
                         expected_sha256 = "435a78193a0ad2e9aaa7f0cfffa22a8317b320aee81fdd44235e1b37afd28d36") {
  for (package in c("data.table", "jsonlite")) {
    if (!requireNamespace(package, quietly = TRUE)) {
      stop("Required R package is not installed: ", package, call. = FALSE)
    }
  }
  check_integer <- function(value, name, minimum = 0L) {
    if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
        !is.finite(value) || value != floor(value) || value < minimum ||
        value > .Machine$integer.max) {
      stop(name, " must be one integer >= ", minimum, ".", call. = FALSE)
    }
    as.integer(value)
  }
  sample_size <- check_integer(sample_size, "sample_size", 2L)
  sample_seed <- check_integer(sample_seed, "sample_seed")
  split_seed <- check_integer(split_seed, "split_seed")
  if (!is.character(expected_sha256) || length(expected_sha256) != 1L ||
      is.na(expected_sha256) || !grepl("^[[:xdigit:]]{64}$", expected_sha256)) {
    stop("expected_sha256 must be one 64-character SHA-256 checksum.",
         call. = FALSE)
  }
  expected_sha256 <- tolower(expected_sha256)
  if (!is.character(project_dir) || length(project_dir) != 1L ||
      is.na(project_dir) || !dir.exists(project_dir)) {
    stop("project_dir must be an existing directory.", call. = FALSE)
  }
  project_dir <- normalizePath(project_dir, mustWork = TRUE)
  source_file <- file.path(project_dir, "data", "raw", "pubg", "train_V2.csv")
  if (!file.exists(source_file)) {
    stop("Missing input: ", source_file, call. = FALSE)
  }

  # Restore RNG configuration and state so sourcing/calling this module does not
  # alter random choices made by another part of the analysis.
  previous_rng_kind <- RNGkind()
  if (identical(previous_rng_kind[[2L]], "Box-Muller")) {
    stop("Cannot preserve the Box-Muller normal cache. ",
         "Run preparation in a separate Rscript session using default Inversion.",
         call. = FALSE)
  }
  had_random_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_random_seed) {
    previous_random_seed <- get(".Random.seed", envir = .GlobalEnv,
                                inherits = FALSE)
  }
  on.exit({
    do.call(RNGkind, as.list(previous_rng_kind))
    if (had_random_seed) {
      assign(".Random.seed", previous_random_seed, envir = .GlobalEnv)
    } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")

  id_fields <- c("Id", "groupId", "matchId", "matchType")
  integer_fields <- c("numGroups", "maxPlace", "DBNOs", "revives", "kills",
                      "boosts", "heals")
  numeric_fields <- c("winPlacePerc", "damageDealt", "walkDistance",
                      "rideDistance", "swimDistance")
  required_fields <- c(id_fields, "winPlacePerc", "numGroups", "maxPlace",
                       "DBNOs", "revives", "kills", "damageDealt",
                       "walkDistance", "boosts", "heals", "rideDistance",
                       "swimDistance")
  header <- names(data.table::fread(source_file, nrows = 0L, showProgress = FALSE))
  missing_fields <- setdiff(required_fields, header)
  if (length(missing_fields)) {
    stop("Missing required input columns: ", paste(missing_fields, collapse = ", "),
         call. = FALSE)
  }
  if (anyDuplicated(header)) {
    stop("Input column names are duplicated.", call. = FALSE)
  }

  checksum_command <- Sys.which("shasum")
  if (!nzchar(checksum_command)) {
    stop("shasum is required to verify the source SHA-256 checksum.",
         call. = FALSE)
  }
  checksum_output <- system2(checksum_command,
                            c("-a", "256", shQuote(source_file)),
                            stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(checksum_output, "status")) ||
      length(checksum_output) != 1L ||
      !grepl("^[[:xdigit:]]{64}[[:space:]]", checksum_output)) {
    stop("Could not calculate the source SHA-256 checksum.", call. = FALSE)
  }
  source_sha256 <- tolower(substr(checksum_output, 1L, 64L))
  if (!identical(source_sha256, expected_sha256)) {
    stop("Raw training data checksum differs from the expected input. ",
         "No processed files were written.", call. = FALSE)
  }

  raw <- data.table::fread(
    source_file, select = required_fields,
    colClasses = list(character = id_fields,
                      numeric = c(integer_fields, numeric_fields)),
    na.strings = c("", "NA"), showProgress = FALSE
  )
  if (!all(vapply(raw[, c(integer_fields, numeric_fields), with = FALSE],
                  is.numeric, logical(1)))) {
    stop("Required numeric/count input columns contain non-numeric values.",
         call. = FALSE)
  }
  missing_counts <- vapply(raw, function(column) sum(is.na(column)), integer(1))
  non_target_missing <- missing_counts[setdiff(required_fields, "winPlacePerc")]
  if (any(non_target_missing > 0L)) {
    stop("Missing values in required non-target input columns: ",
         paste(names(non_target_missing)[non_target_missing > 0L], collapse = ", "),
         ". No records were silently filtered.", call. = FALSE)
  }
  if (any(vapply(raw[, id_fields, with = FALSE],
                 function(column) any(!nzchar(column)), logical(1)))) {
    stop("Required identifier columns contain empty values.", call. = FALSE)
  }
  if (any(!is.finite(raw$winPlacePerc[!is.na(raw$winPlacePerc)])) ||
      any(raw$winPlacePerc < 0 | raw$winPlacePerc > 1, na.rm = TRUE)) {
    stop("Non-missing winPlacePerc values must be finite and in [0, 1].",
         call. = FALSE)
  }
  if (any(vapply(raw[, c(integer_fields, setdiff(numeric_fields, "winPlacePerc")),
                        with = FALSE],
                 function(column) any(!is.finite(column) | column < 0),
                 logical(1)))) {
    stop("Required behavior/count fields must be finite and non-negative.",
         call. = FALSE)
  }
  invalid_integer_fields <- vapply(raw[, integer_fields, with = FALSE],
    function(column) any(column != floor(column) | column > .Machine$integer.max),
    logical(1))
  if (any(invalid_integer_fields)) {
    stop("Required count fields must contain integers within R's integer range: ",
         paste(names(invalid_integer_fields)[invalid_integer_fields], collapse = ", "),
         ".", call. = FALSE)
  }
  for (field in integer_fields) {
    data.table::set(raw, j = field, value = as.integer(raw[[field]]))
  }

  global_match_count <- data.table::uniqueN(raw$matchId)
  global_group_count <- data.table::uniqueN(raw, by = c("matchId", "groupId"))
  global_duplicate_ids <- sum(duplicated(raw$Id))
  if (global_duplicate_ids > 0L) {
    stop("The source contains duplicated player-record Id values.", call. = FALSE)
  }
  solo_raw <- raw[raw$matchType == "solo-fpp"]
  solo_raw_match_count <- data.table::uniqueN(solo_raw$matchId)
  solo_target_missing <- sum(is.na(solo_raw$winPlacePerc))
  excluded_target_rows <- as.data.frame(
    solo_raw[is.na(solo_raw$winPlacePerc),
             c("Id", "groupId", "matchId", "maxPlace", "numGroups"), with = FALSE]
  )
  solo <- solo_raw[!is.na(solo_raw$winPlacePerc)]
  valid_match_ids <- sort(unique(solo$matchId), method = "radix")
  if (length(valid_match_ids) < sample_size) {
    stop("Only ", length(valid_match_ids), " valid solo-fpp matches are available; ",
         sample_size, " were requested.", call. = FALSE)
  }

  group_counts <- solo[, list(
    group_size = .N,
    target_values = data.table::uniqueN(winPlacePerc)
  ), by = c("matchId", "groupId")]
  match_counts <- solo[, list(n_records = .N), by = "matchId"]
  multi_groups <- group_counts[group_counts$group_size > 1L]
  constant_fields <- names(solo)[vapply(solo, function(column) {
    data.table::uniqueN(column) == 1L
  }, logical(1))]
  constant_values <- lapply(solo[, constant_fields, with = FALSE], function(column) {
    column[[1L]]
  })
  anomaly_counts <- list(
    kills_without_movement = sum(solo$kills > 0L & solo$walkDistance == 0 &
                                  solo$rideDistance == 0 & solo$swimDistance == 0),
    walk_distance_over_10000_m = sum(solo$walkDistance > 10000)
  )

  set.seed(sample_seed)
  selected_match_ids <- sort(sample(valid_match_ids, size = sample_size,
                                    replace = FALSE), method = "radix")
  n_train_matches <- as.integer(floor(0.8 * sample_size))
  set.seed(split_seed)
  train_match_ids <- sample(selected_match_ids, size = n_train_matches,
                            replace = FALSE)
  matches <- as.data.frame(match_counts[match_counts$matchId %in% selected_match_ids])
  matches$split <- ifelse(matches$matchId %in% train_match_ids, "train", "test")
  matches <- matches[order(matches$matchId, method = "radix"),
                     c("matchId", "split", "n_records")]
  rownames(matches) <- NULL

  sample_data <- solo[solo$matchId %in% selected_match_ids]
  sample_data <- merge(sample_data,
                       group_counts[, c("matchId", "groupId", "group_size"),
                                    with = FALSE],
                       by = c("matchId", "groupId"), all.x = TRUE, sort = FALSE)
  sample_data <- merge(sample_data, data.table::as.data.table(matches)[,
                                    c("matchId", "split"), with = FALSE],
                       by = "matchId", all.x = TRUE, sort = FALSE)
  data.table::set(sample_data, j = "group_weight",
                  value = 1 / sample_data$group_size)
  data.table::setcolorder(sample_data, c(required_fields, "group_size",
                                       "group_weight", "split"))
  data.table::setorderv(sample_data, c("matchId", "groupId", "Id"))
  sample_data <- as.data.frame(sample_data)
  rownames(sample_data) <- NULL
  validate_sample_mode(sample_data)
  if (nrow(sample_data) != sum(matches$n_records) ||
      anyNA(sample_data) || length(unique(sample_data$matchId)) != sample_size) {
    stop("Internal sampling integrity check failed.", call. = FALSE)
  }
  sample_group_counts <- data.table::as.data.table(sample_data)[,
    list(group_size = .N, sum_group_weight = sum(group_weight),
         stored_group_size = group_size[[1L]],
         declared_group_size = data.table::uniqueN(group_size),
         split_count = data.table::uniqueN(split)), by = c("matchId", "groupId")]
  if (any(abs(sample_group_counts$sum_group_weight - 1) > 1e-12) ||
      any(sample_group_counts$stored_group_size != sample_group_counts$group_size) ||
      any(sample_group_counts$declared_group_size != 1L) ||
      any(sample_group_counts$split_count != 1L) ||
      any(vapply(split(sample_data$split, sample_data$matchId),
                 function(values) length(unique(values)) != 1L, logical(1)))) {
    stop("Internal group-weight or match-split integrity check failed.",
         call. = FALSE)
  }

  audit <- list(
    source = list(
      path = "data/raw/pubg/train_V2.csv", sha256 = source_sha256,
      reference_sha256 = expected_sha256,
      matches_reference_sha256 = identical(source_sha256, expected_sha256),
      bytes = unname(file.info(source_file)$size),
      n_records = nrow(raw), n_columns = length(header),
      columns = header, read_columns = required_fields,
      missing_by_read_column = as.list(missing_counts),
      target_missing = unname(missing_counts[["winPlacePerc"]]),
      n_matches = global_match_count, n_match_group_pairs = global_group_count,
      duplicate_record_ids = global_duplicate_ids
    ),
    eligibility = list(
      match_type = "solo-fpp", raw_records = nrow(solo_raw),
      raw_matches = solo_raw_match_count,
      excluded_missing_target_records = solo_target_missing,
      excluded_rows = excluded_target_rows,
      valid_records = nrow(solo), valid_matches = length(valid_match_ids),
      n_match_group_pairs = nrow(group_counts),
      multi_record_groups = nrow(multi_groups),
      records_in_multi_record_groups = sum(multi_groups$group_size),
      matches_with_multi_record_groups = data.table::uniqueN(multi_groups$matchId),
      groups_with_inconsistent_target = sum(group_counts$target_values > 1L),
      constant_fields = constant_values,
      anomaly_candidates_retained = anomaly_counts,
      filtering_rule = "Keep solo-fpp records with observed winPlacePerc; retain all groups and extreme behavior values."
    ),
    sampling = list(
      sample_size_matches = sample_size, sample_seed = sample_seed,
      split_seed = split_seed,
      rng_kind = list(kind = "Mersenne-Twister", normal_kind = "Inversion",
                      sample_kind = "Rejection"),
      input_match_order = "sort unique valid matchId using radix order",
      train_matches = n_train_matches,
      test_matches = sample_size - n_train_matches,
      records = nrow(sample_data),
      train_records = sum(sample_data$split == "train"),
      test_records = sum(sample_data$split == "test"),
      n_match_group_pairs = nrow(sample_group_counts),
      weighting_rule = "group_weight = 1 / number of retained records in the same (matchId, groupId)",
      sampling_unit = "whole match; every eligible record in a selected match is retained",
      output_record_order = "matchId, groupId, Id"
    ),
    software = list(
      R = R.version.string,
      data_table = as.character(utils::packageVersion("data.table")),
      jsonlite = as.character(utils::packageVersion("jsonlite"))
    )
  )

  output_dir <- file.path(project_dir, "data", "processed")
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(output_dir)) {
    stop("Could not create output directory: ", output_dir, call. = FALSE)
  }
  output_files <- file.path(output_dir, c("pubg_sample.csv", "selected_matches.csv",
                                         "data_audit.json"))
  staging_dir <- tempfile(".preparation-", tmpdir = output_dir)
  if (!dir.create(staging_dir, showWarnings = FALSE)) {
    stop("Could not create preparation staging directory.", call. = FALSE)
  }
  cleanup_staging <- TRUE
  on.exit({
    if (cleanup_staging) unlink(staging_dir, recursive = TRUE)
  }, add = TRUE)
  staged_files <- file.path(staging_dir, basename(output_files))
  data.table::fwrite(sample_data, staged_files[[1L]],
                     na = "NA")
  data.table::fwrite(matches, staged_files[[2L]],
                     na = "NA")
  jsonlite::write_json(audit, staged_files[[3L]],
                       auto_unbox = TRUE, pretty = TRUE, digits = 16,
                       null = "null")

  # Check the existing targets explicitly: rename can replace a read-only file
  # when its directory is writable. Only ordinary writable files may be replaced.
  had_output <- file.exists(output_files)
  output_links <- Sys.readlink(output_files)
  linked_output <- !is.na(output_links) & nzchar(output_links)
  if (any(linked_output) || any(had_output & !file_test("-f", output_files))) {
    stop("Preparation output targets must be ordinary files, not directories or links.",
         call. = FALSE)
  }
  if (any(file.access(output_files[had_output], mode = 2L) != 0L)) {
    stop("Existing preparation output files must be writable.", call. = FALSE)
  }
  backup_dir <- file.path(staging_dir, "previous")
  if (!dir.create(backup_dir, showWarnings = FALSE)) {
    stop("Could not create preparation backup directory.", call. = FALSE)
  }
  backup_files <- file.path(backup_dir, basename(output_files))
  for (i in which(had_output)) {
    if (!file.copy(output_files[[i]], backup_files[[i]],
                   copy.mode = TRUE, copy.date = TRUE)) {
      stop("Could not back up preparation output: ", output_files[[i]],
           call. = FALSE)
    }
    if (!Sys.chmod(staged_files[[i]], file.info(output_files[[i]])$mode)) {
      stop("Could not preserve preparation output permissions: ", output_files[[i]],
           call. = FALSE)
    }
  }

  # Publish only after all writes and backups succeed. A caught publication
  # error or interrupt restores the prior files (or removes new targets).
  attempted <- rep(FALSE, length(output_files))
  rollback_outputs <- function(condition) suspendInterrupts({
    # Keep recovery copies if restoration itself fails unexpectedly.
    cleanup_staging <<- FALSE
    rollback_failed <- character()
    for (i in which(attempted)) {
      restored <- tryCatch({
        if (had_output[[i]]) {
          file.copy(backup_files[[i]], output_files[[i]], overwrite = TRUE,
                    copy.mode = TRUE, copy.date = TRUE)
        } else {
          !file.exists(output_files[[i]]) || file.remove(output_files[[i]])
        }
      }, error = function(rollback_error) FALSE,
         interrupt = function(rollback_interrupt) FALSE)
      if (!isTRUE(restored)) rollback_failed <- c(rollback_failed, output_files[[i]])
    }
    if (length(rollback_failed)) {
      stop("Preparation output publication failed: ", conditionMessage(condition),
           ". Could not restore: ", paste(rollback_failed, collapse = ", "),
           ". Recovery copies are retained in ", backup_dir, ".", call. = FALSE)
    }
    cleanup_staging <<- TRUE
    stop("Preparation output publication failed; previous output state restored: ",
         conditionMessage(condition), call. = FALSE)
  })
  tryCatch(suspendInterrupts({
    for (i in seq_along(output_files)) {
      attempted[[i]] <- TRUE
      if (!file.rename(staged_files[[i]], output_files[[i]])) {
        stop("Could not replace preparation output: ", output_files[[i]],
             call. = FALSE)
      }
    }
  }), error = rollback_outputs, interrupt = rollback_outputs)
  list(data = sample_data, matches = matches, audit = audit)
}
