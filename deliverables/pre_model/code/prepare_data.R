# Reproducible match-level sampling of the PUBG training data.
# Source this file, then call prepare_data(<path to Project>).

prepare_data <- function(project_dir, sample_size = 200L,
                         sample_seed = 6101L, split_seed = 6102L) {
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

  raw <- data.table::fread(
    source_file, select = required_fields,
    colClasses = list(character = id_fields, integer = integer_fields,
                      numeric = numeric_fields),
    na.strings = c("", "NA"), showProgress = FALSE
  )
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

  known_sha256 <- "435a78193a0ad2e9aaa7f0cfffa22a8317b320aee81fdd44235e1b37afd28d36"
  audit <- list(
    source = list(
      path = "data/raw/pubg/train_V2.csv", sha256 = source_sha256,
      reference_sha256 = known_sha256,
      matches_reference_sha256 = identical(source_sha256, known_sha256),
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
  data.table::fwrite(sample_data, file.path(output_dir, "pubg_sample.csv"),
                     na = "NA")
  data.table::fwrite(matches, file.path(output_dir, "selected_matches.csv"),
                     na = "NA")
  jsonlite::write_json(audit, file.path(output_dir, "data_audit.json"),
                       auto_unbox = TRUE, pretty = TRUE, digits = 16,
                       null = "null")
  list(data = sample_data, matches = matches, audit = audit)
}
