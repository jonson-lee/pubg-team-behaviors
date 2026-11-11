# Run from any directory:
# Rscript /absolute/path/to/Project/code/tests/test_statistics.R
file_argument <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(file_argument) != 1L) stop("Run this file with Rscript.")
test_path <- normalizePath(gsub("~+~", " ", sub("^--file=", "", file_argument),
                                fixed = TRUE))
source(file.path(dirname(test_path), "..", "statistics.R"))

assert_equal <- function(actual, expected, tolerance = 1e-9) {
  result <- all.equal(actual, expected, tolerance = tolerance,
                      check.attributes = FALSE)
  if (!isTRUE(result)) stop(paste(result, collapse = "; "))
}
assert_error <- function(expression, pattern) {
  error <- tryCatch({ force(expression); NULL }, error = identity)
  stopifnot(inherits(error, "error"), grepl(pattern, conditionMessage(error)))
}

# Analytic reference, not a second implementation of the sandwich algorithm.
# Centered x gives X'X = diag(6,10). The three cluster scores are
# (3/5,-1/2), (-1,0), (2/5,1/2), and CR1 correction is 15/8.
small <- data.frame(x = c(-2, -1, 0, 0, 1, 2), y = c(0, 2, 1, 3, 4, 5))
small_cluster <- rep(c("A", "B", "C"), each = 2)
small_model <- lm(y ~ x, small)
small_result <- cluster_inference(small_model, small_cluster)
assert_equal(coef(small_model), c(5 / 2, 6 / 5))
assert_equal(small_result$vcov,
             matrix(c(19 / 240, -1 / 320, -1 / 320, 3 / 320), 2))
assert_equal(small_result$coefficients$ci_low,
             coef(small_model) - qt(0.975, 2) * sqrt(c(19 / 240, 3 / 320)))
assert_equal(small_result$coefficients$p_value,
             2 * pt(abs(c(5 / 2, 6 / 5) / sqrt(c(19 / 240, 3 / 320))),
                    df = 2, lower.tail = FALSE))
stopifnot(nrow(small_result$joint_tests) == 0L)

# Weighted analytic reference: X'WX=diag(8,10); the cluster scores are
# (17/20,-7/8), (-3/2,0), (13/20,7/8). N remains six rows, not sum(w).
small$w <- c(1, 1, 2, 2, 1, 1)
weighted_model <- lm(y ~ x, small, weights = w)
weighted_result <- cluster_inference(weighted_model, small_cluster)
assert_equal(coef(weighted_model), c(19 / 8, 6 / 5))
assert_equal(weighted_result$vcov,
             matrix(c(2037 / 20480, -21 / 5120, -21 / 5120, 147 / 5120), 2))
assert_equal(cluster_inference(lm(y ~ x, small, weights = 37 * w),
                               small_cluster)$vcov, weighted_result$vcov)
assert_equal(cluster_inference(weighted_model,
                               c(101, 101, -3, -3, 900, 900))$vcov,
             weighted_result$vcov)

# H1 has a closed-form two-restriction reference. Orthogonal columns give
# beta=(1,2,3), and V[kills,damageDealt] has diag 7/6, off-diag -7/20.
# Hence Wald/2=34860/4459. Omitting covariance would instead give 39/7.
h1_data <- data.frame(
  kills = rep(c(-1, 1), 4), damageDealt = rep(c(-1, -1, 1, 1), each = 2),
  y = c(-2, 0, -3, -3, 3, 9, -2, 6)
)
h1_result <- cluster_inference(lm(y ~ kills + damageDealt, h1_data),
                                rep(seq_len(4), each = 2))
assert_equal(coef(lm(y ~ kills + damageDealt, h1_data)), c(1, 2, 3))
assert_equal(h1_result$vcov[2:3, 2:3],
             matrix(c(7 / 6, -7 / 20, -7 / 20, 7 / 6), 2))
assert_equal(h1_result$joint_tests$statistic, 34860 / 4459)
assert_equal(h1_result$joint_tests$p_value,
             pf(34860 / 4459, 2, 3, lower.tail = FALSE))
stopifnot(h1_result$joint_tests$hypothesis == "H1",
          h1_result$joint_tests$df_num == 2L,
          abs(h1_result$joint_tests$statistic - 39 / 7) > 1)

# H2 uses repeated Hadamard rows. X'X=16I and the four cluster residual
# loadings sum to zero. The restriction covariance is 5/48 times
# [[10,3,11],[3,10,7],[11,7,18]], giving beta'V^-1 beta/3 = 204/125.
hadamard <- rbind(c(1, 1, 1), c(1, -1, -1), c(-1, 1, -1), c(-1, -1, 1))
loadings <- rbind(c(1, 2, 3), c(2, -1, 1), c(-1, 1, -2), c(-2, -2, -2))
h2_data <- as.data.frame(hadamard[rep(seq_len(4), 4), ])
names(h2_data) <- c("walkDistance", "boosts", "heals")
h2_data$y <- 5 + as.numeric(as.matrix(h2_data) %*% c(2, 1, 3)) +
  unlist(lapply(seq_len(4), function(g) {
    c(1, -1, 2, -2)[g] + as.numeric(hadamard %*% loadings[g, ])
  }))
h2_result <- cluster_inference(lm(y ~ walkDistance + boosts + heals, h2_data),
                                rep(seq_len(4), each = 4))
assert_equal(h2_result$vcov[2:4, 2:4],
             5 / 48 * matrix(c(10, 3, 11, 3, 10, 7, 11, 7, 18), 3))
assert_equal(h2_result$joint_tests$statistic, 204 / 125)
stopifnot(h2_result$joint_tests$hypothesis == "H2",
          h2_result$joint_tests$df_num == 3L)

make_fixture <- function(g = 24L, rows = 7L + seq_len(g) %% 6L) {
  set.seed(713)
  match_index <- rep(seq_len(g), rows)
  n <- length(match_index)
  kills <- rpois(n, 2)
  damage <- 55 * kills + rexp(n, 1 / 150)
  walk <- rgamma(n, shape = 2, scale = 450)
  boosts <- rpois(n, 2)
  heals <- rpois(n, 3)
  context <- sample(40:100, g, replace = TRUE)
  effect <- rnorm(g, sd = 0.04)
  data <- data.frame(
    matchId = paste0("match", match_index), numGroups = context[match_index],
    kills = kills, damageDealt = damage, walkDistance = walk,
    boosts = boosts, heals = heals,
    winPlacePerc = 0.2 + 0.001 * context[match_index] + 0.025 * kills +
      0.000025 * damage + 0.0001 * walk + 0.02 * boosts + 0.01 * heals +
      effect[match_index] + rnorm(n, sd = 0.07),
    group_weight = rep(c(1, 1 / 2, 1 / 3, 1 / 4), length.out = n)
  )
  data
}
fixture <- make_fixture()
raw_models <- fit_models(fixture)
stopifnot(identical(names(raw_models), c("context", "combat", "mobility", "full")),
          all(vapply(raw_models, inherits, TRUE, what = "lm")),
          length(attr(raw_models, "formula_labels")) == 4L)
assert_equal(coef(raw_models$full),
             coef(lm(winPlacePerc ~ numGroups + kills + damageDealt +
                       walkDistance + boosts + heals, fixture)))
log_models <- fit_models(fixture, transform = "log1p")
stopifnot("numGroups" %in% names(coef(log_models$full)),
          !"log1p(numGroups)" %in% names(coef(log_models$full)),
          all(paste0("log1p(", unlist(.behavior_blocks), ")") %in%
                names(coef(log_models$full))))
assert_equal(predict(log_models$full, newdata = fixture),
             predict(lm(winPlacePerc ~ numGroups + log1p(kills) +
                          log1p(damageDealt) + log1p(walkDistance) +
                          log1p(boosts) + log1p(heals), fixture)))
log_inference <- cluster_inference(log_models$full, fixture$matchId)
stopifnot(identical(log_inference$joint_tests$hypothesis, c("H1", "H2")),
          identical(log_inference$joint_tests$df_num, c(2L, 3L)))

comparison <- model_comparison(raw_models, fixture)
assert_equal(comparison$metrics$r_squared,
             vapply(raw_models, function(model) summary(model)$r.squared, 0.0))
assert_equal(comparison$metrics$adj_r_squared,
             vapply(raw_models, function(model) summary(model)$adj.r.squared, 0.0))
assert_equal(comparison$h3$D,
             summary(raw_models$mobility)$r.squared -
               summary(raw_models$combat)$r.squared)
weighted_models <- fit_models(fixture, group_equal = TRUE)
weighted_comparison <- model_comparison(weighted_models, fixture, weighted = TRUE)
assert_equal(weighted_comparison$metrics$r_squared,
             vapply(weighted_models, function(model) summary(model)$r.squared, 0.0))
scaled_fixture <- fixture
scaled_fixture$group_weight <- 12 * fixture$group_weight
scaled_models <- fit_models(scaled_fixture, group_equal = TRUE)
assert_equal(model_comparison(scaled_models, scaled_fixture, weighted = TRUE)$h3$D,
             weighted_comparison$h3$D)
assert_equal(cluster_inference(weighted_models$full, fixture$matchId)$vcov,
             cluster_inference(scaled_models$full, fixture$matchId)$vcov)

# Independent bootstrap reference physically replicates sampled matches, then
# uses lm/summary. This catches a bootstrap that discards repeated matches, and
# checks the optimized moment calculations without reusing their formulas.
reference_bootstrap <- function(data, reps, seed, weighted = FALSE, log = FALSE) {
  set.seed(seed)
  matches <- unique(data$matchId)
  result <- numeric(reps)
  unique_count <- integer(reps)
  sampled_rows <- integer(reps)
  for (replicate in seq_len(reps)) {
    selected <- sample.int(length(matches), length(matches), replace = TRUE)
    indices <- unlist(lapply(selected, function(index) {
      which(data$matchId == matches[index])
    }), use.names = FALSE)
    sample <- data[indices, , drop = FALSE]
    w <- if (weighted) sample$group_weight else rep(1, nrow(sample))
    if (log) {
      combat <- lm(winPlacePerc ~ numGroups + log1p(kills) + log1p(damageDealt),
                    sample, weights = w)
      mobility <- lm(winPlacePerc ~ numGroups + log1p(walkDistance) +
                      log1p(boosts) + log1p(heals), sample, weights = w)
    } else {
      combat <- lm(winPlacePerc ~ numGroups + kills + damageDealt,
                    sample, weights = w)
      mobility <- lm(winPlacePerc ~ numGroups + walkDistance + boosts + heals,
                      sample, weights = w)
    }
    result[replicate] <- summary(mobility)$r.squared - summary(combat)$r.squared
    unique_count[replicate] <- length(unique(selected))
    sampled_rows[replicate] <- length(indices)
  }
  list(D = result, n_clusters_unique = unique_count, n_rows = sampled_rows)
}

set.seed(801)
original_rng <- .Random.seed
bootstrap <- bootstrap_h3(fixture, reps = 60L)
stopifnot(identical(original_rng, .Random.seed))
bootstrap_repeat <- bootstrap_h3(fixture, reps = 60L)
stopifnot(identical(bootstrap, bootstrap_repeat),
          all(bootstrap$draws$n_clusters_unique < 24L))
saved_kind <- RNGkind()
saved_rng <- .Random.seed
RNGkind("L'Ecuyer-CMRG", "Inversion", "Rejection")
set.seed(901)
alternate_rng <- .Random.seed
alternate_kind <- RNGkind()
alternate_bootstrap <- bootstrap_h3(fixture, reps = 60L)
stopifnot(identical(alternate_bootstrap$draws, bootstrap$draws),
          identical(RNGkind(), alternate_kind),
          identical(.Random.seed, alternate_rng))
do.call(RNGkind, as.list(saved_kind))
assign(".Random.seed", saved_rng, envir = .GlobalEnv)
# A cached Box-Muller normal variate is not contained in .Random.seed. Reject
# this caller configuration without changing either the seed or cached value.
for (uniform_kind in c("Mersenne-Twister", "L'Ecuyer-CMRG")) {
  RNGkind(uniform_kind, "Box-Muller", "Rejection")
  set.seed(713L)
  invisible(rnorm(1L))
  expected_normal <- rnorm(1L)
  RNGkind(uniform_kind, "Box-Muller", "Rejection")
  set.seed(713L)
  invisible(rnorm(1L))
  previous_kind <- RNGkind()
  previous_seed <- .Random.seed
  assert_error(bootstrap_h3(fixture, reps = 1L), "Box-Muller")
  stopifnot(identical(RNGkind(), previous_kind), identical(.Random.seed, previous_seed),
            identical(rnorm(1L), expected_normal))
}
do.call(RNGkind, as.list(saved_kind))
assign(".Random.seed", saved_rng, envir = .GlobalEnv)
assert_equal(bootstrap$estimate, comparison$h3$D)
assert_equal(c(bootstrap$ci_low, bootstrap$ci_high),
             quantile(bootstrap$draws$D, c(0.025, 0.975), type = 7))
reference <- reference_bootstrap(fixture, 8L, 6103L)
assert_equal(bootstrap$draws$D[1:8], reference$D)
assert_equal(bootstrap$draws$n_clusters_unique[1:8], reference$n_clusters_unique)
assert_equal(bootstrap$draws$n_rows[1:8], reference$n_rows)
weighted_log_bootstrap <- bootstrap_h3(fixture, reps = 8L, seed = 6105L,
                                       group_equal = TRUE, transform = "log1p")
weighted_log_reference <- reference_bootstrap(fixture, 8L, 6105L,
                                             weighted = TRUE, log = TRUE)
assert_equal(weighted_log_bootstrap$draws$D, weighted_log_reference$D)
assert_equal(bootstrap_h3(scaled_fixture, reps = 8L, seed = 6105L,
                          group_equal = TRUE, transform = "log1p")$draws$D,
             weighted_log_bootstrap$draws$D)
stopifnot(!identical(bootstrap_h3(fixture, reps = 60L, seed = 7000L)$draws$D,
                     bootstrap$draws$D))

# Compare one-predictor combat models with direct OLS fits and a bootstrap
# that materializes every sampled match, including repeated matches.
representative_cases <- list(
  list(variable = "kills", transform = "raw", term = "kills",
       combat = winPlacePerc ~ numGroups + kills,
       mobility = winPlacePerc ~ numGroups + walkDistance + boosts + heals,
       full = winPlacePerc ~ numGroups + kills + walkDistance + boosts + heals),
  list(variable = "damageDealt", transform = "log1p", term = "log1p(damageDealt)",
       combat = winPlacePerc ~ numGroups + log1p(damageDealt),
       mobility = winPlacePerc ~ numGroups + log1p(walkDistance) + log1p(boosts) + log1p(heals),
       full = winPlacePerc ~ numGroups + log1p(damageDealt) +
         log1p(walkDistance) + log1p(boosts) + log1p(heals))
)
for (case in representative_cases) {
  models <- fit_models(fixture, transform = case$transform, combat_variables = case$variable)
  direct <- lapply(case[c("combat", "mobility", "full")], lm, data = fixture)
  for (model in names(direct)) {
    stopifnot(identical(names(coef(models[[model]])), names(coef(direct[[model]]))))
    assert_equal(coef(models[[model]]), coef(direct[[model]]))
  }
  r2 <- vapply(direct, function(model) summary(model)$r.squared, 0.0)
  comparison <- model_comparison(models, fixture, combat_variables = case$variable)
  assert_equal(comparison$h3$delta_combat, r2["full"] - r2["mobility"])
  assert_equal(comparison$h3$delta_mobility, r2["full"] - r2["combat"])
  inference <- cluster_inference(models$full, fixture$matchId, combat_variables = case$variable)
  stopifnot(identical(inference$joint_tests$hypothesis, c("H1", "H2")),
            identical(inference$joint_tests$df_num, c(1L, 3L)),
            inference$joint_tests$terms[1L] == case$term)
  assert_equal(inference$joint_tests$statistic[1L],
               inference$coefficients$t[inference$coefficients$term == case$term]^2)

  representative_bootstrap <- bootstrap_h3(
    fixture, reps = 8L, seed = 6103L, transform = case$transform,
    combat_variables = case$variable
  )
  set.seed(6103L)
  matches <- unique(fixture$matchId)
  direct_draws <- replicate(8L, {
    drawn <- sample.int(length(matches), length(matches), replace = TRUE)
    rows <- unlist(lapply(matches[drawn], function(id) which(fixture$matchId == id)),
                   use.names = FALSE)
    sampled_data <- fixture[rows, , drop = FALSE]
    summary(lm(case$mobility, sampled_data))$r.squared -
      summary(lm(case$combat, sampled_data))$r.squared
  })
  assert_equal(representative_bootstrap$estimate, comparison$h3$D)
  assert_equal(representative_bootstrap$draws$D, direct_draws)
  assert_equal(c(representative_bootstrap$ci_low, representative_bootstrap$ci_high),
               quantile(direct_draws, c(0.025, 0.975), type = 7))
}
for (invalid_combat in list(character(), "boosts", c("kills", "kills"))) {
  assert_error(fit_models(fixture, combat_variables = invalid_combat), "combat_variables")
}

invalid <- fixture
invalid$kills[1] <- NA_real_
assert_error(fit_models(invalid), "finite")
invalid <- fixture
invalid$group_weight[1] <- 0
assert_error(fit_models(invalid, group_equal = TRUE), "positive")
assert_error(cluster_inference(small_model, rep(1, 6)), "two clusters")
assert_error(bootstrap_h3(fixture, reps = 1.5), "positive integer")

# Benchmark the intended scale: exactly 200 matches and 19,000 rows. No timing
# threshold is asserted because execution hardware is outside statistical QA.
large_fixture <- make_fixture(g = 200L, rows = rep(95L, 200))
timing <- system.time(large_bootstrap <- bootstrap_h3(large_fixture))
stopifnot(nrow(large_bootstrap$draws) == 1000L,
          large_bootstrap$metadata$matches_per_draw == 200L,
          all(large_bootstrap$draws$n_rows == 19000L),
          all(is.finite(large_bootstrap$draws$D)))
cat("PASS: analytic OLS/WLS CR1 references; joint H1/H2 covariance; transforms;\n")
cat("      weight/cluster invariance; paired cluster duplication; H3 identity; RNG.\n")
cat(sprintf("Benchmark: 19,000 rows, 200 matches, 1,000 draws: %.3f seconds.\n",
             timing[["elapsed"]]))
