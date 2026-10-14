# Run from any directory. All fixtures and generated files stay in a temporary project.
file_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_argument) != 1L) stop("Run this file with Rscript.")
test_path <- normalizePath(gsub("~+~", " ", sub("^--file=", "", file_argument),
                                fixed = TRUE))
project_dir <- dirname(dirname(dirname(test_path)))
source(file.path(project_dir, "code", "prepare_data.R"))

assert_error <- function(expression, pattern = NULL) {
  error <- tryCatch({ force(expression); NULL }, error = identity)
  stopifnot(inherits(error, "error"))
  if (!is.null(pattern)) {
    stopifnot(grepl(pattern, conditionMessage(error), ignore.case = TRUE))
  }
}

run_preparation_checks <- function() {
  fixture_dir <- tempfile("pubg-preparation-tests-")
  dir.create(file.path(fixture_dir, "data", "raw", "pubg"), recursive = TRUE)
  dir.create(file.path(fixture_dir, "data", "processed"), recursive = TRUE)
  dir.create(file.path(fixture_dir, "code"), recursive = TRUE)
  on.exit(unlink(fixture_dir, recursive = TRUE), add = TRUE)

  source_file <- file.path(fixture_dir, "data", "raw", "pubg", "train_V2.csv")
  generated_files <- file.path("data", "processed", c("pubg_sample.csv", "selected_matches.csv",
                                                        "data_audit.json"))
  write_sentinels <- function() {
    for (filename in generated_files) {
      writeLines(paste("existing output", filename), file.path(fixture_dir, filename))
    }
  }
  assert_sentinels <- function() {
    for (filename in generated_files) {
      stopifnot(identical(readLines(file.path(fixture_dir, filename)),
                          paste("existing output", filename)))
    }
  }
  checksum <- function() {
    command <- Sys.which("shasum")
    stopifnot(nzchar(command))
    output <- system2(command, c("-a", "256", shQuote(source_file)),
                      stdout = TRUE, stderr = TRUE)
    stopifnot(is.null(attr(output, "status")), length(output) == 1L,
              grepl("^[[:xdigit:]]{64}[[:space:]]", output))
    tolower(substr(output, 1L, 64L))
  }
  write_fixture <- function(data) {
    data.table::fwrite(data, source_file, na = "NA")
    checksum()
  }

  # Reused group IDs across matches exercise the composite group key. The first
  # shared group loses only its missing-target record; a wholly missing-target
  # match and a non-solo match must never enter the eligible match population.
  n_matches <- 200L
  n <- 4L * n_matches
  fixture <- data.frame(
    Id = sprintf("id%04d", seq_len(n)),
    groupId = rep(c("shared", "shared", "second", "third"), n_matches),
    matchId = rep(sprintf("match%03d", seq_len(n_matches)), each = 4L),
    matchType = "solo-fpp", winPlacePerc = rep(c(0.5, 0.5, 0.8, 0.9), n_matches),
    numGroups = 3L, maxPlace = 3L, DBNOs = 0L, revives = 0L, kills = 1L,
    damageDealt = 100, walkDistance = 100, boosts = 1L, heals = 1L,
    rideDistance = 0, swimDistance = 0
  )
  fixture$winPlacePerc[[1L]] <- NA_real_
  excluded <- fixture[1:2, ]
  excluded$Id <- c("missing-only", "other-mode")
  excluded$matchId <- c("missing-match", "other-match")
  excluded$groupId <- "only-group"
  excluded$numGroups <- excluded$maxPlace <- 1L
  excluded$winPlacePerc <- c(NA_real_, 0.5)
  excluded$matchType <- c("solo-fpp", "squad-fpp")
  fixture <- rbind(fixture, excluded)
  expected_sha256 <- write_fixture(fixture)

  # An unreviewed source must fail before replacing any existing output, both
  # through the function and through the preparation command-line entry point.
  write_sentinels()
  assert_error(prepare_data(fixture_dir), "SHA-256|checksum")
  assert_sentinels()
  scripts <- c("prepare_data.R", "run_preparation.R")
  stopifnot(all(file.copy(file.path(project_dir, "code", scripts),
                          file.path(fixture_dir, "code"))))
  for (entry in "run_preparation.R") {
    output <- suppressWarnings(system2(
      file.path(R.home("bin"), "Rscript"),
      shQuote(file.path(fixture_dir, "code", entry)), stdout = TRUE, stderr = TRUE
    ))
    stopifnot(!is.null(attr(output, "status")), attr(output, "status") != 0L,
              any(grepl("SHA-256|checksum", output, ignore.case = TRUE)))
    assert_sentinels()
  }

  for (invalid in list(NA_character_, "", "1234", paste(rep("g", 64L), collapse = ""),
                       c(expected_sha256, expected_sha256), 42, NULL)) {
    assert_error(prepare_data(fixture_dir, expected_sha256 = invalid), "expected_sha256")
    assert_sentinels()
  }
  for (invalid in list(1L, 2.5, NA_real_, Inf, -1, "20", c(20L, 21L))) {
    assert_error(prepare_data(fixture_dir, sample_size = invalid,
                              expected_sha256 = expected_sha256), "sample_size")
    assert_sentinels()
  }
  for (argument in c("sample_seed", "split_seed")) {
    for (invalid in list(-1L, 1.5, NA_real_, Inf)) {
      options <- list(project_dir = fixture_dir, expected_sha256 = expected_sha256)
      options[[argument]] <- invalid
      assert_error(do.call(prepare_data, options), argument)
      assert_sentinels()
    }
  }

  assert_bad_fixture <- function(data) {
    hash <- write_fixture(data)
    assert_error(prepare_data(fixture_dir, sample_size = 20L, expected_sha256 = hash))
    assert_sentinels()
  }
  integer_fields <- c("numGroups", "maxPlace", "DBNOs", "revives", "kills", "boosts", "heals")
  for (field in integer_fields) {
    for (invalid in c(0.5, NA_real_, Inf, -1, as.double(.Machine$integer.max) + 1)) {
      bad <- fixture
      bad[[field]][[2L]] <- invalid
      assert_bad_fixture(bad)
    }
  }
  for (field in c("damageDealt", "walkDistance", "rideDistance", "swimDistance")) {
    for (invalid in c(NA_real_, Inf, -1)) {
      bad <- fixture
      bad[[field]][[2L]] <- invalid
      assert_bad_fixture(bad)
    }
  }
  for (invalid in c(Inf, -0.1, 1.1)) {
    bad <- fixture
    bad$winPlacePerc[[2L]] <- invalid
    assert_bad_fixture(bad)
  }
  for (field in c("Id", "groupId", "matchId", "matchType")) {
    for (invalid in c("", NA_character_)) {
      bad <- fixture
      bad[[field]][[2L]] <- invalid
      assert_bad_fixture(bad)
    }
  }
  bad <- fixture
  bad$Id[[2L]] <- bad$Id[[1L]]
  assert_bad_fixture(bad)
  assert_bad_fixture(fixture[, names(fixture) != "kills"])
  bad <- fixture
  names(bad)[names(bad) == "heals"] <- "kills"
  assert_bad_fixture(bad)

  expected_sha256 <- write_fixture(fixture)
  # Box-Muller keeps a second normal variate outside .Random.seed. Reject it
  # before changing RNG configuration, including when a normal value is cached.
  for (uniform_kind in c("Mersenne-Twister", "L'Ecuyer-CMRG")) {
    RNGkind(uniform_kind, "Box-Muller", "Rejection")
    set.seed(713L)
    invisible(rnorm(1L))
    expected_normal <- rnorm(1L)
    RNGkind(uniform_kind, "Box-Muller", "Rejection")
    set.seed(713L)
    invisible(rnorm(1L))
    before_kind <- RNGkind()
    before_seed <- .Random.seed
    assert_error(prepare_data(fixture_dir, sample_size = 20L,
                              expected_sha256 = expected_sha256), "Box-Muller")
    assert_sentinels()
    stopifnot(identical(RNGkind(), before_kind), identical(.Random.seed, before_seed),
              identical(rnorm(1L), expected_normal))
  }
  RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
  set.seed(713L)
  before_kind <- RNGkind()
  before_seed <- .Random.seed
  result <- prepare_data(fixture_dir, sample_size = 20L,
                          expected_sha256 = toupper(expected_sha256))
  stopifnot(identical(RNGkind(), before_kind), identical(.Random.seed, before_seed),
            identical(result$audit$source$reference_sha256, expected_sha256),
            isTRUE(result$audit$source$matches_reference_sha256),
            nrow(result$matches) == 20L,
            sum(result$matches$split == "train") == 16L,
            sum(result$matches$split == "test") == 4L,
            !anyNA(result$data), !anyDuplicated(result$data$Id),
            !any(result$data$matchId %in% excluded$matchId),
            result$audit$eligibility$excluded_missing_target_records == 2L,
            result$audit$eligibility$valid_matches == n_matches,
            all(vapply(result$data[integer_fields], is.integer, logical(1))))
  # Use the same mode validator as the preparation module, with synthetic data.
  stopifnot(is.null(validate_sample_mode(result$data)))
  invalid_modes <- list(
    all_squad = function(data) { data$matchType[] <- "squad-fpp"; data },
    one_squad = function(data) { data$matchType[1L] <- "squad-fpp"; data },
    missing_column = function(data) { data$matchType <- NULL; data },
    missing_value = function(data) { data$matchType[1L] <- NA_character_; data },
    empty_value = function(data) { data$matchType[1L] <- ""; data }
  )
  for (modify in invalid_modes) {
    assert_error(validate_sample_mode(modify(result$data)), "Sample mode contract violation")
  }

  train_matches <- unique(result$data$matchId[result$data$split == "train"])
  test_matches <- unique(result$data$matchId[result$data$split == "test"])
  stopifnot(!length(intersect(train_matches, test_matches)))
  for (match_id in result$matches$matchId) {
    eligible <- fixture$matchId == match_id & !is.na(fixture$winPlacePerc)
    selected <- result$data[result$data$matchId == match_id, ]
    stopifnot(setequal(selected$Id, fixture$Id[eligible]),
              length(unique(selected$split)) == 1L,
              nrow(selected) == result$matches$n_records[result$matches$matchId == match_id])
  }
  groups <- split(result$data, interaction(result$data$matchId, result$data$groupId,
                                           drop = TRUE))
  for (group in groups) {
    stopifnot(all(group$group_size == nrow(group)),
              all(group$group_weight == 1 / nrow(group)),
              abs(sum(group$group_weight) - 1) < 1e-12)
  }

  repeated <- prepare_data(fixture_dir, sample_size = 20L, expected_sha256 = expected_sha256)
  stopifnot(identical(result$data, repeated$data), identical(result$matches, repeated$matches))

  # Successful publication changes the complete bundle, while failed staging or
  # publication must preserve the previous bytes and leave no temporary outputs.
  output_dir <- file.path(fixture_dir, "data", "processed")
  output_files <- file.path(output_dir, c("pubg_sample.csv", "selected_matches.csv",
                                         "data_audit.json"))
  snapshot_outputs <- function() {
    lapply(output_files, function(path) readBin(path, "raw", n = file.info(path)$size))
  }
  assert_no_staging <- function() {
    stopifnot(!any(grepl("^\\.preparation-", list.files(output_dir, all.files = TRUE))))
  }
  assert_previous_outputs <- function(snapshot) {
    stopifnot(identical(snapshot_outputs(), snapshot))
    assert_no_staging()
  }
  original_outputs <- snapshot_outputs()
  changed <- prepare_data(fixture_dir, sample_size = 20L, sample_seed = 7101L,
                           expected_sha256 = expected_sha256)
  changed_outputs <- snapshot_outputs()
  saved_data <- as.data.frame(data.table::fread(output_files[[1L]]))
  saved_matches <- as.data.frame(data.table::fread(output_files[[2L]]))
  saved_audit <- jsonlite::read_json(output_files[[3L]], simplifyVector = TRUE)
  stopifnot(all(!vapply(seq_along(output_files), function(i) {
              identical(original_outputs[[i]], changed_outputs[[i]])
            }, logical(1))),
            isTRUE(all.equal(saved_data, changed$data, check.attributes = FALSE)),
            identical(saved_matches, changed$matches),
            setequal(unique(saved_data$matchId), saved_matches$matchId),
            saved_audit$sampling$sample_seed == 7101L,
            saved_audit$sampling$records == nrow(saved_data))
  assert_no_staging()
  invisible(prepare_data(fixture_dir, sample_size = 20L,
                         expected_sha256 = expected_sha256))
  assert_previous_outputs(original_outputs)

  prepare_with_mock <- function(bindings) {
    mock_environment <- new.env(parent = .GlobalEnv)
    source(file.path(project_dir, "code", "prepare_data.R"), local = mock_environment)
    list2env(bindings, envir = mock_environment)
    mock_environment$prepare_data(fixture_dir, sample_size = 20L, sample_seed = 7101L,
                                  expected_sha256 = expected_sha256)
  }
  for (index in 2:3) {
    local({
      target <- output_files[[index]]
      on.exit(Sys.chmod(target, "0644"), add = TRUE)
      stopifnot(Sys.chmod(target, "0444"), file.access(target, mode = 2L) != 0L)
      assert_error(prepare_data(fixture_dir, sample_size = 20L, sample_seed = 7101L,
                                expected_sha256 = expected_sha256), "must be writable")
      assert_previous_outputs(original_outputs)
    })
    local({
      target <- output_files[[index]]
      previous <- tempfile("previous-target-", tmpdir = fixture_dir)
      stopifnot(file.rename(target, previous), dir.create(target))
      on.exit({
        unlink(target, recursive = TRUE)
        stopifnot(file.rename(previous, target))
      }, add = TRUE)
      assert_error(prepare_data(fixture_dir, sample_size = 20L, sample_seed = 7101L,
                                expected_sha256 = expected_sha256), "ordinary files")
      stopifnot(dir.exists(target), !length(list.files(target)),
                identical(readBin(previous, "raw", n = file.info(previous)$size),
                          original_outputs[[index]]))
      for (other in setdiff(seq_along(output_files), index)) {
        stopifnot(identical(readBin(output_files[[other]], "raw",
                                   n = file.info(output_files[[other]])$size),
                            original_outputs[[other]]))
      }
      assert_no_staging()
    })
    assert_previous_outputs(original_outputs)
  }
  assert_error(prepare_with_mock(list(dir.create = function(path, ...) {
    created <- base::dir.create(path, ...)
    if (created && startsWith(basename(path), ".preparation-")) {
      stopifnot(base::dir.create(file.path(path, "selected_matches.csv")))
    }
    created
  })))
  assert_previous_outputs(original_outputs)
  assert_error(prepare_with_mock(list(file.copy = function(from, to, ...) {
    if (basename(to) == "data_audit.json") return(FALSE)
    base::file.copy(from, to, ...)
  })), "back up")
  assert_previous_outputs(original_outputs)

  # Throw after the third rename has already happened, exercising rollback even
  # when an operation reports an error after it has changed the target.
  published_targets <- character()
  fail_publication <- function(from, to) {
    replaced <- base::file.rename(from, to)
    if (replaced) published_targets <<- c(published_targets, basename(to))
    if (basename(to) == "data_audit.json") stop("Simulated publication failure.")
    replaced
  }
  assert_error(prepare_with_mock(list(file.rename = fail_publication)),
               "previous output state restored")
  stopifnot(identical(published_targets, basename(output_files)))
  assert_previous_outputs(original_outputs)

  assert_error(prepare_with_mock(list(file.rename = function(from, to) {
    replaced <- base::file.rename(from, to)
    if (basename(to) == "selected_matches.csv") {
      stop(structure(list(message = "Simulated publication interrupt.", call = NULL),
                     class = c("interrupt", "condition")))
    }
    replaced
  })), "previous output state restored")
  assert_previous_outputs(original_outputs)

  # If rollback itself cannot restore a target, retain every recovery copy and
  # include its directory in the error instead of deleting the previous data.
  publication_error <- tryCatch(prepare_with_mock(list(
    file.rename = fail_publication,
    file.copy = function(from, to, ...) {
      if (basename(dirname(from)) == "previous" &&
          basename(to) == "selected_matches.csv") return(FALSE)
      base::file.copy(from, to, ...)
    }
  )), error = identity)
  recovery_dirs <- list.files(output_dir, pattern = "^\\.preparation-",
                              full.names = TRUE, all.files = TRUE)
  stopifnot(inherits(publication_error, "error"), length(recovery_dirs) == 1L)
  recovery_files <- normalizePath(file.path(recovery_dirs, "previous", basename(output_files)))
  stopifnot(grepl(dirname(recovery_files[[1L]]), conditionMessage(publication_error),
                  fixed = TRUE),
            identical(lapply(recovery_files, function(path) {
              readBin(path, "raw", n = file.info(path)$size)
            }), original_outputs),
            all(base::file.copy(recovery_files, output_files, overwrite = TRUE,
                                 copy.mode = TRUE, copy.date = TRUE)))
  unlink(recovery_dirs, recursive = TRUE)
  assert_previous_outputs(original_outputs)

  stopifnot(all(file.remove(output_files)))
  published_targets <- character()
  assert_error(prepare_with_mock(list(file.rename = fail_publication)),
               "previous output state restored")
  stopifnot(identical(published_targets, basename(output_files)), !any(file.exists(output_files)))
  assert_no_staging()
  invisible(prepare_data(fixture_dir, sample_size = 20L,
                         expected_sha256 = expected_sha256))
  assert_previous_outputs(original_outputs)

  reordered_sha256 <- write_fixture(fixture[nrow(fixture):1L, ])
  reordered <- prepare_data(fixture_dir, sample_size = 20L,
                             expected_sha256 = reordered_sha256)
  stopifnot(identical(result$data, reordered$data), identical(result$matches, reordered$matches))

  # The missing record changes only its own retained group size and weight.
  complete <- prepare_data(fixture_dir, expected_sha256 = reordered_sha256)
  first_group <- complete$data[complete$data$matchId == "match001" &
                                 complete$data$groupId == "shared", ]
  stopifnot(nrow(complete$data) == 799L, nrow(first_group) == 1L,
            first_group$group_size == 1L, first_group$group_weight == 1)

  rm(".Random.seed", envir = .GlobalEnv)
  invisible(prepare_data(fixture_dir, sample_size = 20L,
                          expected_sha256 = reordered_sha256))
  stopifnot(!exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
  set.seed(713L)
  before_seed <- .Random.seed
  bad <- fixture
  bad$kills[[2L]] <- -1L
  bad_sha256 <- write_fixture(bad)
  assert_error(prepare_data(fixture_dir, sample_size = 20L, expected_sha256 = bad_sha256))
  stopifnot(identical(RNGkind(), before_kind), identical(.Random.seed, before_seed))
  message("Preparation checks passed: input rejection, integer counts, whole-match sampling, group weights, reproducibility and output rollback.")
}

run_preparation_checks()
