# Base-R statistical core for the solo-fpp analysis. Sourcing defines functions
# only; data loading, output, and the analysis run belong to the main pipeline.
#
# CR1 reference: https://sandwich.r-forge.r-project.org/reference/vcovCL.html
# t/F degrees of freedom: https://www.statsmodels.org/stable/generated/
# statsmodels.regression.linear_model.RegressionResults.get_robustcov_results.html

.behavior_blocks <- list(
  combat = c("kills", "damageDealt"),
  mobility = c("walkDistance", "boosts", "heals")
)

.analysis_blocks <- function(combat_variables) {
  if (!is.character(combat_variables) || !length(combat_variables) ||
      anyNA(combat_variables) || anyDuplicated(combat_variables) ||
      !all(combat_variables %in% .behavior_blocks$combat)) {
    stop("combat_variables must contain a nonempty, unique selection of kills and damageDealt.")
  }
  list(combat = combat_variables, mobility = .behavior_blocks$mobility)
}

.validate_analysis_data <- function(data, group_equal = FALSE, transform = "raw",
                                    combat_variables = .behavior_blocks$combat) {
  transform <- match.arg(transform, c("raw", "log1p"))
  behavior <- unlist(.analysis_blocks(combat_variables), use.names = FALSE)
  required <- c("winPlacePerc", "numGroups", behavior)
  if (group_equal) required <- c(required, "group_weight")
  missing <- setdiff(required, names(data))
  if (length(missing)) stop("Missing columns: ", paste(missing, collapse = ", "))
  if (!is.data.frame(data) || nrow(data) < 8L) {
    stop("Analysis data must be a data.frame with at least eight rows.")
  }
  for (variable in required) {
    if (!is.numeric(data[[variable]]) || any(!is.finite(data[[variable]]))) {
      stop(variable, " must contain only finite numeric values.")
    }
  }
  if (group_equal && any(data$group_weight <= 0)) {
    stop("group_weight must be strictly positive.")
  }
  if (transform == "log1p") {
    for (variable in behavior) {
      if (any(data[[variable]] < 0)) {
        stop(variable, " must be nonnegative for the log1p analysis.")
      }
    }
  }
  invisible(transform)
}

.analysis_formulas <- function(transform = "raw", combat_variables = .behavior_blocks$combat) {
  transform <- match.arg(transform, c("raw", "log1p"))
  terms <- lapply(.analysis_blocks(combat_variables), function(variables) {
    if (transform == "log1p") paste0("log1p(", variables, ")") else variables
  })
  predictors <- list(
    context = "numGroups",
    combat = c("numGroups", terms$combat),
    mobility = c("numGroups", terms$mobility),
    full = c("numGroups", terms$combat, terms$mobility)
  )
  lapply(predictors, stats::reformulate, response = "winPlacePerc")
}

fit_models <- function(data, transform = "raw", group_equal = FALSE,
                       combat_variables = .behavior_blocks$combat) {
  transform <- .validate_analysis_data(data, group_equal, transform, combat_variables)
  formulas <- .analysis_formulas(transform, combat_variables)
  analysis_data <- data
  analysis_data$.analysis_weight <- if (group_equal) data$group_weight else 1
  models <- lapply(formulas, function(formula) {
    model <- stats::lm(formula, data = analysis_data, weights = .analysis_weight,
                       na.action = stats::na.fail)
    attr(model, "analysis_transform") <- transform
    attr(model, "analysis_group_equal") <- group_equal
    model
  })
  attr(models, "formula_labels") <- vapply(
    formulas, function(formula) paste(deparse(formula), collapse = " "), ""
  )
  models
}

cluster_inference <- function(model, cluster, combat_variables = .behavior_blocks$combat) {
  if (!inherits(model, "lm")) stop("model must be an lm object.")
  blocks <- .analysis_blocks(combat_variables)
  design <- stats::model.matrix(model)
  residual <- as.numeric(stats::residuals(model))
  n <- nrow(design)
  k <- ncol(design)
  if (length(cluster) != n || anyNA(cluster)) {
    stop("cluster must identify every fitted row, without missing values.")
  }
  if (model$rank != k || anyNA(stats::coef(model))) {
    stop("CR1 inference requires a full-rank model.")
  }
  weights <- stats::weights(model)
  if (is.null(weights)) weights <- rep(1, n)
  if (any(!is.finite(weights)) || any(weights <= 0)) {
    stop("CR1 inference requires strictly positive finite row weights.")
  }
  cluster_id <- match(cluster, unique(cluster))
  g <- max(cluster_id)
  if (g < 2L || n <= k) stop("CR1 requires at least two clusters and N > K.")

  # For WLS the estimating function is x_i * w_i * e_i. Multiplying
  # every weight by a constant cancels between the meat and the bread.
  cluster_scores <- rowsum(design * (weights * residual), cluster_id,
                           reorder = FALSE)
  bread <- chol2inv(chol(crossprod(design * sqrt(weights))))
  correction <- g / (g - 1) * (n - 1) / (n - k)
  covariance <- correction * bread %*% crossprod(cluster_scores) %*% bread
  covariance <- (covariance + t(covariance)) / 2
  dimnames(covariance) <- list(colnames(design), colnames(design))

  estimate <- stats::coef(model)
  standard_error <- sqrt(pmax(diag(covariance), 0))
  t_statistic <- estimate / standard_error
  df <- g - 1L
  critical <- stats::qt(0.975, df)
  coefficients <- data.frame(
    term = names(estimate), estimate = unname(estimate),
    cluster_se = unname(standard_error), t = unname(t_statistic), df = df,
    p_value = unname(2 * stats::pt(abs(t_statistic), df, lower.tail = FALSE)),
    ci_low = unname(estimate - critical * standard_error),
    ci_high = unname(estimate + critical * standard_error),
    row.names = NULL
  )

  # Both raw and formula-level log1p terms retain their original block meaning.
  original_terms <- sub("^log1p\\(([^)]+)\\)$", "\\1", names(estimate))
  joint_tests <- data.frame(
    hypothesis = character(), terms = character(), statistic = numeric(),
    df_num = integer(), df_denom = integer(), p_value = numeric()
  )
  for (block in names(blocks)) {
    variables <- blocks[[block]]
    index <- match(variables, original_terms)
    if (anyNA(index)) next
    q <- length(index)
    block_covariance <- covariance[index, index, drop = FALSE]
    block_estimate <- estimate[index]
    # A singular restriction covariance cannot support the requested q-df test.
    statistic <- tryCatch(
      as.numeric(crossprod(block_estimate,
                          solve(block_covariance, block_estimate))) / q,
      error = function(error) NA_real_
    )
    joint_tests <- rbind(joint_tests, data.frame(
      hypothesis = if (block == "combat") "H1" else "H2",
      terms = paste(names(estimate)[index], collapse = "; "),
      statistic = statistic, df_num = q, df_denom = df,
      p_value = stats::pf(statistic, q, df, lower.tail = FALSE)
    ))
  }
  list(
    coefficients = coefficients, joint_tests = joint_tests, vcov = covariance,
    metadata = list(
      estimator = "CR1", clusters = g, observations = n, rank = k,
      finite_sample_correction = correction,
      inference = "Approximate cluster-robust t(G-1) and Wald/q F(q,G-1)",
      joint_null = "All coefficients in the named block equal zero",
      assumptions = "Independent matches; sufficiently many clusters"
    )
  )
}

model_comparison <- function(models, data, weighted = FALSE,
                             combat_variables = .behavior_blocks$combat) {
  required_models <- c("context", "combat", "mobility", "full")
  if (!all(required_models %in% names(models))) {
    stop("models must contain context, combat, mobility, and full.")
  }
  .validate_analysis_data(data, group_equal = weighted, combat_variables = combat_variables)
  weights <- if (weighted) data$group_weight else rep(1, nrow(data))
  response <- data$winPlacePerc
  center <- sum(weights * response) / sum(weights)
  tss <- sum(weights * (response - center)^2)
  if (tss <= 0) stop("R-squared requires a nonconstant response.")
  n <- nrow(data)
  metrics <- do.call(rbind, lapply(required_models, function(name) {
    model <- models[[name]]
    prediction <- stats::predict(model, newdata = data)
    if (any(!is.finite(prediction))) stop("Nonfinite prediction for ", name)
    r_squared <- 1 - sum(weights * (response - prediction)^2) / tss
    data.frame(
      model = name, n = n, rank = model$rank, r_squared = r_squared,
      adj_r_squared = if (n > model$rank) {
        1 - (1 - r_squared) * (n - 1) / (n - model$rank)
      } else NA_real_
    )
  }))
  r2 <- stats::setNames(metrics$r_squared, metrics$model)
  # Both increments condition on the opposite behavior block and numGroups.
  delta_combat <- unname(r2["full"] - r2["mobility"])
  delta_mobility <- unname(r2["full"] - r2["combat"])
  list(
    metrics = metrics,
    increments = data.frame(
      block = c("combat", "mobility"),
      delta_r_squared = c(delta_combat, delta_mobility)
    ),
    h3 = data.frame(delta_combat = delta_combat, delta_mobility = delta_mobility,
                    D = delta_mobility - delta_combat),
    metadata = list(
      weighted = weighted,
      r_squared = "1 - weighted RSS / weighted centered TSS",
      adjusted_r_squared = "Descriptive row-based adjustment, not a cluster test",
      h3 = "D = (R2_full - R2_combat) - (R2_full - R2_mobility)"
    )
  )
}

.cluster_moments <- function(design, response, weights, cluster_id) {
  p <- ncol(design)
  g <- max(cluster_id)
  xx <- matrix(0, nrow = g, ncol = p * p)
  for (j in seq_len(p)) {
    for (k in seq_len(p)) {
      xx[, j + (k - 1L) * p] <- rowsum(
        weights * design[, j] * design[, k], cluster_id, reorder = FALSE
      )[, 1L]
    }
  }
  list(
    xx = xx,
    xy = rowsum(design * (weights * response), cluster_id, reorder = FALSE),
    p = p
  )
}

.r_squared_from_moments <- function(moments, frequencies, weighted_y2, tss) {
  xx <- matrix(as.numeric(crossprod(frequencies, moments$xx)), moments$p)
  xy <- as.numeric(crossprod(frequencies, moments$xy))
  coefficient <- tryCatch(solve(xx, xy), error = function(error) NULL)
  if (is.null(coefficient) || tss <= 0) return(NA_real_)
  rss <- weighted_y2 - sum(coefficient * xy)
  1 - rss / tss
}

bootstrap_h3 <- function(data, reps = 1000L, seed = 6103L,
                         group_equal = FALSE, transform = "raw",
                         combat_variables = .behavior_blocks$combat) {
  transform <- .validate_analysis_data(data, group_equal, transform, combat_variables)
  if (!"matchId" %in% names(data) || anyNA(data$matchId)) {
    stop("matchId must identify every analysis row.")
  }
  if (length(reps) != 1L || !is.finite(reps) || reps < 1 || reps != as.integer(reps)) {
    stop("reps must be a positive integer.")
  }
  if (length(seed) != 1L || !is.finite(seed) || seed != as.integer(seed)) {
    stop("seed must be a finite integer.")
  }
  cluster_id <- match(data$matchId, unique(data$matchId))
  g <- max(cluster_id)
  if (g < 2L) stop("Cluster bootstrap requires at least two matches.")
  weights <- if (group_equal) data$group_weight else rep(1, nrow(data))
  response <- data$winPlacePerc
  formulas <- .analysis_formulas(transform, combat_variables)[c("combat", "mobility")]
  moments <- lapply(formulas, function(formula) {
    design <- stats::model.matrix(formula, data = data)
    # Fixed affine scaling improves normal-equation conditioning, while the
    # intercept ensures identical fitted values and R2 to the unscaled model.
    for (column in seq.int(2L, ncol(design))) {
      scale <- stats::sd(design[, column])
      if (!is.finite(scale) || scale == 0) {
        stop("Bootstrap predictor is constant: ", colnames(design)[column])
      }
      design[, column] <- (design[, column] - mean(design[, column])) / scale
    }
    .cluster_moments(design, response, weights, cluster_id)
  })
  totals <- rowsum(cbind(weight = weights, y = weights * response,
                        y2 = weights * response^2, n = 1),
                   cluster_id, reorder = FALSE)
  evaluate <- function(frequencies) {
    total <- as.numeric(crossprod(frequencies, totals))
    tss <- total[3L] - total[2L]^2 / total[1L]
    r2 <- vapply(moments, .r_squared_from_moments, 0.0,
                 frequencies = frequencies, weighted_y2 = total[3L], tss = tss)
    # The full-model R2 cancels in deltaMobility - deltaCombat, so fitting
    # these two reduced models gives exactly the same paired-bootstrap D.
    unname(r2["mobility"] - r2["combat"])
  }
  estimate <- evaluate(rep(1L, g))
  if (!is.finite(estimate)) stop("H3 is undefined for the original sample.")

  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) previous_seed <- get(".Random.seed", envir = .GlobalEnv)
  previous_kind <- RNGkind()
  if (identical(previous_kind[[2L]], "Box-Muller")) {
    stop("Cannot preserve the Box-Muller normal cache. ",
         "Run analysis in a separate Rscript session using default Inversion.",
         call. = FALSE)
  }
  on.exit({
    do.call(RNGkind, as.list(previous_kind))
    if (had_seed) assign(".Random.seed", previous_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
      rm(".Random.seed", envir = .GlobalEnv)
    }
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(seed)
  draws <- data.frame(replicate = seq_len(reps), D = NA_real_,
                       n_clusters_unique = NA_integer_, n_rows = NA_integer_)
  for (replicate in seq_len(reps)) {
    # Frequency weights retain repeated sampled matches. Each draw samples G
    # matches (200 for the primary sample), never merely their unique IDs.
    frequencies <- tabulate(sample.int(g, g, replace = TRUE), nbins = g)
    draws$D[replicate] <- evaluate(frequencies)
    draws$n_clusters_unique[replicate] <- sum(frequencies > 0)
    draws$n_rows[replicate] <- sum(frequencies * totals[, "n"])
  }
  failures <- sum(!is.finite(draws$D))
  if (failures) {
    stop(failures, " bootstrap fits are singular or have constant response; ",
         "cannot report the requested percentile interval without all draws.")
  }
  interval <- unname(stats::quantile(draws$D, c(0.025, 0.975), type = 7))
  list(
    estimate = estimate, ci_low = interval[1L], ci_high = interval[2L],
    reps = as.integer(reps), seed = as.integer(seed), draws = draws,
    metadata = list(
      matches_per_draw = g, group_equal = group_equal, transform = transform,
      method = "Paired match-cluster bootstrap; 95% percentile interval (type 7)",
      repeated_matches = "Retained through integer frequency multipliers",
      full_model_cancellation = "D = R2_mobility - R2_combat on the same sample"
    )
  )
}
