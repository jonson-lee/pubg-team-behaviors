#!/usr/bin/env Rscript
# IBA6101 PUBG 团队补充建模分析
# Rscript deliverables/modeling/run_team_modeling.R [sample_csv] [output_parent]
# 使用 R 自带包。补充分析源于团队的模型、探索性诊断及项目统计协议。
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
args <- commandArgs(trailingOnly = TRUE)
if (length(file_arg) != 1L || length(args) > 2L) {
  stop("Usage: Rscript run_team_modeling.R [sample_csv] [output_parent]", call. = FALSE)
}
script_path <- normalizePath(
  gsub("~+~", " ", sub("^--file=", "", file_arg), fixed = TRUE),
  mustWork = TRUE
)
script_dir <- dirname(script_path)
input_file <- if (length(args) >= 1L) args[1L] else
  file.path(script_dir, "..", "..", "data", "processed", "pubg_sample.csv")
output_parent <- if (length(args) == 2L) args[2L] else file.path(script_dir, "runs")

run_pubg_analysis <- function(input_file, output_parent) {
  bootstrap_B <- 1000L
  seed <- 6103L
  if (!file.exists(input_file) || dir.exists(input_file)) {
    stop("Provide the fixed pubg_sample.csv as the first argument.", call. = FALSE)
  }
  input_file <- normalizePath(input_file, mustWork = TRUE)
  hash <- unname(tools::md5sum(input_file))
  expected_hash <- "c40153ed85bdc34afc0d99be24eaa740"
  if (!identical(hash, expected_hash)) {
    stop("Sample MD5 mismatch. This supplement requires the original fixed sample.",
         call. = FALSE)
  }
  old_rng <- RNGkind()
  if (identical(old_rng[2L], "Box-Muller")) {
    stop("Use an R session with the Inversion normal RNG (Rscript --vanilla).",
         call. = FALSE)
  }
  old_options <- options(stringsAsFactors = FALSE, digits = 8, warn = 1)
  on.exit(options(old_options), add = TRUE)
  had_seed <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = .GlobalEnv)
  on.exit({
    do.call(RNGkind, as.list(old_rng))
    if (had_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
      rm(list = ".Random.seed", envir = .GlobalEnv)
  }, add = TRUE)

  dir.create(output_parent, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(output_parent)) stop("Cannot create the output parent directory.")
  output_parent <- normalizePath(output_parent, mustWork = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S", tz = "Asia/Shanghai")
  stem <- file.path(output_parent, paste0("modeling_", stamp))
  out <- stem
  suffix <- 0L
  while (!dir.create(out, showWarnings = FALSE)) {
    if (!file.exists(out)) stop("Cannot create the run directory.")
    suffix <- suffix + 1L
    out <- paste0(stem, "_", suffix)
  }
  finished <- FALSE
  on.exit(if (!finished) writeLines(
    "INCOMPLETE. Inspect the R error before using these results.",
    file.path(out, "STATUS.txt"), useBytes = TRUE), add = TRUE)
  writeLines("RUNNING", file.path(out, "STATUS.txt"))
  folders <- c("00_audit", "01_full", "02_train", "03_exploration",
               "04_bootstrap", "05_validation", "06_plots", "07_models")
  for (folder in folders) {
    if (!dir.create(file.path(out, folder))) stop("Cannot create run folder: ", folder)
  }
  csv_out <- function(x, path, row.names = FALSE) {
    write.csv(x, file.path(out, path), row.names = row.names, fileEncoding = "UTF-8")
  }
  txt_out <- function(x, path) {
    writeLines(capture.output(print(x)), file.path(out, path), useBytes = TRUE)
  }
  combine <- function(x) { ans <- do.call(rbind, x); rownames(ans) <- NULL; ans }
  fit_table <- function(models) combine(lapply(names(models), function(nm) {
    m <- models[[nm]]; s <- summary(m)
    data.frame(model = nm, N = nobs(m), K = m$rank, R2 = s$r.squared,
      adj_R2 = s$adj.r.squared, RSE = s$sigma,
      RSS = sum(weights_or_one(m) * residuals(m)^2))
  }))
  weights_or_one <- function(m) if (is.null(m$weights)) rep(1, nobs(m)) else m$weights
  ordinary_coefs <- function(models) combine(lapply(names(models), function(nm) {
    m <- models[[nm]]; s <- coef(summary(m)); ci <- confint(m)
    data.frame(model = nm, variable = rownames(s), estimate = s[, 1],
      conventional_se = s[, 2], t = s[, 3], conventional_p = s[, 4],
      ci_low = ci[, 1], ci_high = ci[, 2], row.names = NULL)
  }))
  # CR1 = G/(G-1) * (N-1)/(N-K) * bread * sum(s_g s_g') * bread。
  # WLS score为 w_i*x_i*u_i，bread为(X'WX)^(-1)。不是CR2。
  cluster_vcov <- function(m, cluster) {
    X <- model.matrix(m); w <- weights_or_one(m); u <- residuals(m)
    n <- nrow(X); k <- ncol(X); g <- length(unique(cluster))
    stopifnot(length(cluster) == n, g > 1L, n > k, m$rank == k)
    scores <- rowsum(X * as.numeric(w * u), as.character(cluster), reorder = FALSE)
    bread <- solve(crossprod(X, X * w))
    V <- (g / (g - 1)) * ((n - 1) / (n - k)) *
      bread %*% crossprod(scores) %*% bread
    dimnames(V) <- list(colnames(X), colnames(X))
    (V + t(V)) / 2
  }
  cluster_coefs <- function(models, cluster) combine(lapply(names(models), function(nm) {
    m <- models[[nm]]; V <- cluster_vcov(m, cluster); b <- coef(m)
    se <- sqrt(diag(V)); df <- length(unique(cluster)) - 1L
    data.frame(model = nm, variable = names(b), estimate = unname(b),
      cluster_se = unname(se), t = unname(b / se), df = df,
      p = unname(2 * pt(abs(b / se), df = df, lower.tail = FALSE)),
      ci_low = unname(b - qt(.975, df) * se),
      ci_high = unname(b + qt(.975, df) * se), row.names = NULL)
  }))
  behavior <- c("kills", "damageDealt", "walkDistance", "boosts", "heals")
  formulas <- list(M0 = winPlacePerc ~ numGroups,
    M1 = winPlacePerc ~ numGroups + kills + damageDealt,
    M2 = winPlacePerc ~ numGroups + walkDistance + boosts + heals,
    M3 = winPlacePerc ~ numGroups + kills + damageDealt + walkDistance + boosts + heals)
  # 公式只使用数据列和base函数，移除对整个运行环境的捕获，减小模型文件。
  for (nm in names(formulas)) environment(formulas[[nm]]) <- baseenv()
  fit_set <- function(d, weighted = FALSE) lapply(formulas, function(f) {
    m <- if (weighted) lm(f, data = d, weights = .group_weight, na.action = na.fail)
      else lm(f, data = d, na.action = na.fail)
    m$call$formula <- f
    m
  })
  # 任何增删变量都显式指定full或train，防止重新求值时读错数据。
  refit <- function(m, change, data) {
    f <- update.formula(formula(m), change)
    z <- lm(f, data = data, na.action = na.fail)
    z$call$formula <- f
    z
  }
  group_tests <- function(m, cluster) {
    V <- cluster_vcov(m, cluster); df <- length(unique(cluster)) - 1L
    sets <- list(H1 = c("kills", "damageDealt"), H2 = c("walkDistance", "boosts", "heals"))
    tests <- combine(lapply(names(sets), function(h) {
      z <- sets[[h]]; b <- coef(m)[z]; q <- length(z)
      Fstat <- as.numeric(crossprod(b, solve(V[z, z, drop = FALSE], b))) / q
      data.frame(hypothesis = h, F = Fstat, df1 = q, df2 = df,
        p = pf(Fstat, q, df, lower.tail = FALSE))
    }))
    tests$p_holm_within_scenario <- p.adjust(tests$p, method = "holm")
    tests
  }
  increments <- function(models) {
    r <- vapply(models, function(m) summary(m)$r.squared, numeric(1))
    combat <- unname(r["M3"] - r["M2"])
    mobility <- unname(r["M3"] - r["M1"])
    data.frame(combat_increment = combat, mobility_increment = mobility, D = mobility - combat)
  }
  nested_table <- function(models, pairs) combine(lapply(pairs, function(p) {
    a <- anova(models[[p[1]]], models[[p[2]]])
    data.frame(comparison = paste(p, collapse = " -> "), added_df = a$Df[2],
      RSS_reduction = a$`Sum of Sq`[2], conventional_F = a$F[2], conventional_p = a$`Pr(>F)`[2])
  }))
  base_pairs <- list(c("M0", "M1"), c("M0", "M2"), c("M0", "M3"),
                     c("M1", "M3"), c("M2", "M3"))
  vif_table <- function(models) combine(lapply(names(models), function(nm) {
    X <- model.matrix(models[[nm]])[, -1L, drop = FALSE]
    v <- vapply(seq_len(ncol(X)), function(j) {
      s <- summary(lm(X[, j] ~ X[, -j, drop = FALSE]))$r.squared
      1 / (1 - s)
    }, numeric(1))
    data.frame(model = nm, variable = colnames(X), VIF = v)
  }))
  validate <- function(models, d) combine(lapply(names(models), function(nm) {
    pred <- as.numeric(predict(models[[nm]], newdata = d)); y <- d$winPlacePerc
    stopifnot(length(pred) == nrow(d), all(is.finite(pred)), all(is.finite(y)))
    e <- y - pred
    data.frame(model = nm, Test_N = nrow(d), Test_matches = length(unique(d$matchId)),
      RMSE = sqrt(mean(e^2)), MAE = mean(abs(e)),
      test_R2 = 1 - sum(e^2) / sum((y - mean(y))^2),
      match_mean_MAE = mean(tapply(abs(e), d$matchId, mean)),
      out_of_bounds_n = sum(pred < 0 | pred > 1),
      out_of_bounds_pct = 100 * mean(pred < 0 | pred > 1),
      weighting = "equal records")
  }))
  # 独立PDF设备保存图片，不依赖Plots窗格尺寸，避免figure margins too large。
  pdf_out <- function(name, fun, width = 10, height = 8) {
    pdf(file.path(out, "06_plots", name), width = width, height = height)
    on.exit(dev.off(), add = TRUE)
    fun()
  }

  # ==================== 2 数据审计 固定原始split ====================
  message("[1/8] 读取数据库并核查整场划分……")
  d <- read.csv(input_file, check.names = FALSE, stringsAsFactors = FALSE)
  vars <- c("winPlacePerc", "numGroups", behavior)
  required <- c(vars, "Id", "matchId", "groupId", "matchType", "split")
  if (!all(required %in% names(d))) stop("数据库缺少必要字段。")
  if (!all(vapply(d[vars], is.numeric, logical(1)))) stop("建模字段必须是数值。")
  stopifnot(nrow(d) == 18935L, !anyNA(d[required]), !anyDuplicated(d$Id),
    all(nzchar(d$Id)), all(nzchar(d$matchId)), all(nzchar(d$groupId)),
    all(vapply(d[vars], function(x) all(is.finite(x)), logical(1))),
    all(d$winPlacePerc >= 0 & d$winPlacePerc <= 1),
    all(as.matrix(d[behavior]) >= 0), all(d$matchType == "solo-fpp"),
    all(d$split %in% c("train", "test")))
  tr <- d[d$split == "train", , drop = FALSE]
  te <- d[d$split == "test", , drop = FALSE]
  stopifnot(nrow(tr) == 15204L, nrow(te) == 3731L,
    length(unique(d$matchId)) == 200L, length(unique(tr$matchId)) == 160L,
    length(unique(te$matchId)) == 40L,
    length(intersect(tr$matchId, te$matchId)) == 0L)
  key <- paste(d$matchId, d$groupId, sep = "::")
  d$.group_size <- as.integer(ave(rep(1L, nrow(d)), key, FUN = length))
  d$.group_weight <- 1 / d$.group_size
  # 组内大小在保留记录上计算；整场划分不拆组，train/test沿用同一组定义。
  tr <- d[d$split == "train", , drop = FALSE]
  te <- d[d$split == "test", , drop = FALSE]
  audit <- data.frame(check = c("records", "matches", "train_records", "test_records",
      "train_matches", "test_matches", "overlapping_matches", "duplicate_Id", "missing_model_values"),
    value = c(nrow(d), length(unique(d$matchId)), nrow(tr), nrow(te),
      length(unique(tr$matchId)), length(unique(te$matchId)), 0, 0, 0))
  csv_out(audit, "00_audit/data_checks.csv")
  csv_out(unique(d[c("matchId", "split")]), "00_audit/match_split.csv")
  csv_out(d[c("Id", "matchId", "groupId", ".group_size", ".group_weight")], "00_audit/record_weights.csv")
  desc <- combine(lapply(vars, function(v) {
    x <- d[[v]]; q <- quantile(x, c(0, .25, .5, .75, .9, .95, .99, 1))
    data.frame(variable = v, N = length(x), mean = mean(x), SD = sd(x),
      zero_n = sum(x == 0), min = q[1], q25 = q[2], median = q[3], q75 = q[4],
      q90 = q[5], q95 = q[6], q99 = q[7], max = q[8], row.names = NULL)
  }))
  csv_out(desc, "00_audit/descriptives_full.csv")
  meta <- c("R运行记录", paste("时间", format(Sys.time(), tz = "Asia/Shanghai")),
    paste("输入", basename(input_file)), paste("输入MD5", hash), paste("Bootstrap B", bootstrap_B),
    paste("Bootstrap seed", seed), "RNG固定Mersenne-Twister / Inversion / Rejection",
    "主推断=全样本CR1；预测=仅训练集拟合；保留原split；不截断预测。")
  if (!file.copy(script_path, file.path(out, "07_models", basename(script_path)))) {
    stop("Cannot copy the analysis script into the run directory.")
  }
  meta <- c(meta, paste("代码MD5", unname(tools::md5sum(script_path))))
  writeLines(meta, file.path(out, "00_audit/run_metadata.txt"), useBytes = TRUE)
  txt_out(sessionInfo(), "00_audit/session_info.txt")

  # ==================== 3 原尺度 log1p 组等权WLS ====================
  message("[2/8] 拟合全样本及训练集四模型，计算CR1和联合检验……")
  log_d <- d; log_tr <- tr; log_te <- te
  for (v in behavior) {
    log_d[[v]] <- log1p(d[[v]]); log_tr[[v]] <- log1p(tr[[v]]); log_te[[v]] <- log1p(te[[v]])
  }
  specifications <- list(OLS_raw = list(full = d, train = tr, test = te, weighted = FALSE),
    OLS_log1p = list(full = log_d, train = log_tr, test = log_te, weighted = FALSE),
    WLS_group = list(full = d, train = tr, test = te, weighted = TRUE))
  all_models <- train_models <- validation <- full_cluster <- full_joint <- list()
  for (s in names(specifications)) {
    spec <- specifications[[s]]
    a <- fit_set(spec$full, spec$weighted); b <- fit_set(spec$train, spec$weighted)
    all_models[[s]] <- a; train_models[[s]] <- b
    full_cluster[[s]] <- cluster_coefs(a, d$matchId)
    full_joint[[s]] <- group_tests(a$M3, d$matchId)
    csv_out(fit_table(a), paste0("01_full/models_", s, ".csv"))
    csv_out(ordinary_coefs(a), paste0("01_full/coefficients_conventional_", s, ".csv"))
    csv_out(full_cluster[[s]], paste0("01_full/coefficients_cluster_", s, ".csv"))
    csv_out(full_joint[[s]], paste0("01_full/joint_cluster_", s, ".csv"))
    csv_out(increments(a), paste0("01_full/increments_", s, ".csv"))
    csv_out(fit_table(b), paste0("02_train/models_", s, ".csv"))
    csv_out(ordinary_coefs(b), paste0("02_train/coefficients_conventional_", s, ".csv"))
    csv_out(cluster_coefs(b, tr$matchId), paste0("02_train/coefficients_cluster_", s, ".csv"))
    csv_out(group_tests(b$M3, tr$matchId), paste0("02_train/joint_cluster_", s, ".csv"))
    validation[[s]] <- validate(b, spec$test)
    csv_out(validation[[s]], paste0("05_validation/validation_", s, ".csv"))
  }
  a <- all_models$OLS_raw; b <- train_models$OLS_raw
  csv_out(nested_table(a, base_pairs), "01_full/anova_conventional_OLS_raw.csv")
  csv_out(nested_table(b, base_pairs), "02_train/anova_conventional_OLS_raw.csv")
  csv_out(increments(b), "02_train/increments_OLS_raw.csv")
  csv_out(cor(tr[vars]), "02_train/correlation_OLS_raw.csv", row.names = TRUE)
  csv_out(cor(d[vars]), "01_full/correlation_OLS_raw.csv", row.names = TRUE)
  csv_out(vif_table(list(M1 = b$M1, M3 = b$M3,
    no_damage = refit(b$M3, . ~ . - damageDealt, tr), no_kills = refit(b$M3, . ~ . - kills, tr))),
    "03_exploration/VIF_train.csv")
  csv_out(vif_table(list(M1 = a$M1, M3 = a$M3,
    no_damage = refit(a$M3, . ~ . - damageDealt, d))), "03_exploration/VIF_full.csv")

  # ==================== 4 击杀系数路径 FWL 与系数分解 ====================
  message("[3/8] 控制路径、辅助回归和FWL……")
  paths <- list(
    full_single_add = list(M1 = a$M1, plus_walk = refit(a$M1, . ~ . + walkDistance, d),
      plus_boost = refit(a$M1, . ~ . + boosts, d), plus_heals = refit(a$M1, . ~ . + heals, d), M3 = a$M3),
    train_sequential = list(M1 = b$M1, plus_walk = refit(b$M1, . ~ . + walkDistance, tr),
      plus_walk_boost = refit(b$M1, . ~ . + walkDistance + boosts, tr), M3 = b$M3),
    train_delete_one = list(M3 = b$M3, no_walk = refit(b$M3, . ~ . - walkDistance, tr),
      no_boost = refit(b$M3, . ~ . - boosts, tr), no_heals = refit(b$M3, . ~ . - heals, tr),
      no_damage = refit(b$M3, . ~ . - damageDealt, tr)))
  for (nm in names(paths)) {
    z <- ordinary_coefs(paths[[nm]])
    z <- merge(z[z$variable == "kills", ], fit_table(paths[[nm]])[c("model", "N", "R2")],
               by = "model", sort = FALSE)
    csv_out(z, paste0("03_exploration/kills_", nm, ".csv"))
  }
  auxiliary <- fwl <- list()
  for (scope in c("full", "train")) {
    dx <- if (scope == "full") d else tr
    mx <- if (scope == "full") a$M3 else b$M3
    au <- lm(damageDealt ~ kills + numGroups + walkDistance + boosts + heals, data = dx)
    no_damage <- refit(mx, . ~ . - damageDealt, dx)
    delta <- unname(coef(au)["kills"])
    decomposition <- unname(coef(mx)["kills"] + coef(mx)["damageDealt"] * delta)
    actual <- unname(coef(no_damage)["kills"])
    rx <- resid(lm(kills ~ numGroups + damageDealt + walkDistance + boosts + heals, data = dx))
    ry <- resid(lm(winPlacePerc ~ numGroups + damageDealt + walkDistance + boosts + heals, data = dx))
    fm <- lm(ry ~ rx)
    stopifnot(abs(actual - decomposition) < 1e-10,
      abs(unname(coef(fm)["rx"] - coef(mx)["kills"])) < 1e-10)
    auxiliary[[scope]] <- au; fwl[[scope]] <- fm
    csv_out(ordinary_coefs(list(auxiliary = au)), paste0("03_exploration/auxiliary_", scope, ".csv"))
    csv_out(data.frame(delta = delta, no_damage_kills = actual, decomposed_kills = decomposition,
      difference = actual - decomposition, FWL_slope = unname(coef(fm)["rx"])),
      paste0("03_exploration/decomposition_FWL_", scope, ".csv"))
    if (scope == "train") {
      pdf_out("03_FWL_kills_train.pdf", function() {
        plot(rx, ry, pch = 16, cex = .35, col = rgb(0, 0, 0, .15),
          xlab = "Residualized kills", ylab = "Residualized placement", main = "FWL partial regression")
        abline(fm, col = "red", lwd = 2)
      })
    }
  }

  # ==================== 5 删变量 二次模型 Cook敏感性 ====================
  message("[4/8] 删变量、二次项和高影响记录检查……")
  extended <- list(M3 = b$M3,
    no_damage = refit(b$M3, . ~ . - damageDealt, tr),
    no_kills = refit(b$M3, . ~ . - kills, tr),
    no_damage_quadratic = refit(b$M3, . ~ . - damageDealt + I(kills^2), tr),
    full_quadratic = refit(b$M3, . ~ . + I(kills^2), tr))
  csv_out(fit_table(extended), "03_exploration/extended_models_train.csv")
  csv_out(ordinary_coefs(extended), "03_exploration/extended_coefficients_conventional_train.csv")
  csv_out(cluster_coefs(extended, tr$matchId), "03_exploration/extended_coefficients_cluster_train.csv")
  csv_out(as.data.frame(drop1(b$M3, test = "F")), "03_exploration/drop1_M3_train.csv", row.names = TRUE)
  ext_pairs <- list(c("no_damage", "M3"), c("no_kills", "M3"),
    c("M3", "full_quadratic"), c("no_kills", "full_quadratic"),
    c("no_damage", "no_damage_quadratic"), c("no_damage_quadratic", "full_quadratic"))
  csv_out(nested_table(extended, ext_pairs), "03_exploration/extended_anova_conventional_train.csv")
  csv_out(data.frame(probability = c(0, .25, .5, .75, .9, .95, .99, 1),
    kills = unname(quantile(tr$kills, c(0, .25, .5, .75, .9, .95, .99, 1)))),
    "03_exploration/kills_quantiles_train.csv")
  sensitive <- list(); cook_summary <- list()
  for (nm in c("M3", "full_quadratic")) {
    m <- extended[[nm]]; cd <- cooks.distance(m); cutoff <- 4 / nobs(m)
    keep <- is.finite(cd) & cd <= cutoff
    sm <- lm(formula(m), data = tr[keep, , drop = FALSE], na.action = na.fail)
    sensitive[[nm]] <- sm
    csv_out(data.frame(Id = tr$Id, matchId = tr$matchId, Cook = unname(cd),
      threshold = cutoff, candidate = !keep), paste0("03_exploration/cook_records_", nm, ".csv"))
    cook_summary[[nm]] <- data.frame(model = nm, threshold = cutoff, candidates = sum(!keep),
      candidate_pct = 100 * mean(!keep), maximum_Cook = max(cd), retained_N = sum(keep))
    csv_out(cluster_coefs(list(sensitivity = sm), tr$matchId[keep]),
      paste0("03_exploration/sensitivity_cluster_", nm, ".csv"))
  }
  csv_out(combine(cook_summary), "03_exploration/cook_summary_train.csv")
  csv_out(ordinary_coefs(sensitive), "03_exploration/sensitivity_conventional_train.csv")
  csv_out(fit_table(sensitive), "03_exploration/sensitivity_models_train.csv")
  turning <- function(m) -unname(coef(m)["kills"]) / (2 * unname(coef(m)["I(kills^2)"]))
  csv_out(data.frame(model = c("full_quadratic", "no_damage_quadratic", "Cook_sensitivity_quadratic"),
    conditional_turning_point = c(turning(extended$full_quadratic),
      turning(extended$no_damage_quadratic), turning(sensitive$full_quadratic))),
    "03_exploration/quadratic_turning_points.csv")

  # ==================== 6 H3 配对整场bootstrap ====================
  # 每次抽200场且保留整场记录。重复抽中的比赛贡献按抽中次数累加。
  # 预先汇总每场X'WX、X'Wy、y'Wy，在线性代数上等价于复制整场再拟合。
  # 同一批抽样用于三个设定；WLS组权重固定于原比赛组，重复场次不缩小权重。
  message("[5/8] H3配对整场bootstrap（", bootstrap_B, "次，seed=", seed, "）……")
  RNGkind(kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  set.seed(seed)
  match_ids <- unique(d$matchId); G <- length(match_ids)
  draws <- replicate(bootstrap_B, sample.int(G, G, replace = TRUE))
  stopifnot(identical(dim(draws), c(as.integer(G), as.integer(bootstrap_B))))
  saveRDS(list(seed = seed, match_ids = match_ids, draws = draws,
    description = "每列一次抽样；整数为match_ids的位置；三个设定共用"),
    file.path(out, "04_bootstrap", "paired_match_draws.rds"))
  groups <- match(as.character(d$matchId), match_ids)
  # 预汇总交叉积，数值尺度缩放降低numGroups/距离/伤害造成的条件数。
  bootstrap_suff <- function(dx, weighted) {
    X <- model.matrix(formulas$M3, dx); y <- dx$winPlacePerc
    scales <- apply(abs(X), 2, max); scales[scales == 0] <- 1
    X <- sweep(X, 2, scales, "/")
    Z <- cbind(X, .response = y)
    w <- if (weighted) dx$.group_weight else rep(1, nrow(dx))
    p <- ncol(Z); S <- matrix(0, G, p * p)
    for (i in seq_len(p)) for (j in seq_len(p)) {
      agg <- rowsum(w * Z[, i] * Z[, j], groups, reorder = TRUE)
      S[, (j - 1L) * p + i] <- agg[, 1]
    }
    counts <- tabulate(groups, nbins = G)
    idx <- lapply(formulas, function(f) match(colnames(model.matrix(f, dx)), colnames(X)))
    evaluate <- function(mult) {
      A <- matrix(as.numeric(crossprod(mult, S)), p, p)
      yy <- A[p, p]; tss <- yy - A[1, p]^2 / A[1, 1]
      if (!is.finite(tss) || tss <= 0) stop("bootstrap响应方差不为正。")
      r <- vapply(idx, function(ix) {
        beta <- solve(A[ix, ix, drop = FALSE], A[ix, p, drop = FALSE])
        rss <- yy - as.numeric(crossprod(A[ix, p], beta))
        1 - rss / tss
      }, numeric(1))
      c(N = sum(mult * counts), r,
        combat_increment = unname(r["M3"] - r["M2"]),
        mobility_increment = unname(r["M3"] - r["M1"]),
        D = unname(r["M2"] - r["M1"]))
    }
    # 在全部比赛各取一次时，应与lm/lm.wfit的R²完全对应（允许浮点误差）。
    original <- evaluate(rep(1, G))
    direct <- vapply(fit_set(dx, weighted), function(m) summary(m)$r.squared, numeric(1))
    stopifnot(max(abs(original[names(direct)] - direct)) < 1e-8)
    list(evaluate = evaluate)
  }
  boots <- h3 <- list()
  for (s in names(specifications)) {
    spec <- specifications[[s]]; helper <- bootstrap_suff(spec$full, spec$weighted)
    z <- vector("list", bootstrap_B)
    for (i in seq_len(bootstrap_B)) {
      z[[i]] <- helper$evaluate(tabulate(draws[, i], nbins = G))
      if (i %% 250L == 0L) message("  ", s, " ", i, "/", bootstrap_B)
    }
    boots[[s]] <- data.frame(iteration = seq_len(bootstrap_B), do.call(rbind, z), row.names = NULL)
    h3[[s]] <- cbind(increments(all_models[[s]]), data.frame(B = bootstrap_B, seed = seed,
      ci_low = unname(quantile(boots[[s]]$D, .025)), ci_high = unname(quantile(boots[[s]]$D, .975))))
    csv_out(boots[[s]], paste0("04_bootstrap/bootstrap_", s, ".csv"))
    csv_out(h3[[s]], paste0("04_bootstrap/H3_", s, ".csv"))
  }
  # ==================== 7 留出比较 诊断图 与历史结果核对 ====================
  message("[6/8] 输出留出比较和PDF图……")
  ext_val <- validate(extended, te)
  csv_out(ext_val, "05_validation/extended_models.csv")
  candidates <- rbind(validation$OLS_raw[validation$OLS_raw$model == "M2", ], ext_val,
    transform(validation$OLS_log1p[validation$OLS_log1p$model %in% c("M2", "M3"), ],
      model = paste0(model, "_log1p")),
    transform(validation$WLS_group[validation$WLS_group$model == "M3", ], model = "M3_WLS_group"))
  candidates <- candidates[order(candidates$RMSE), ]; rownames(candidates) <- NULL
  csv_out(candidates, "05_validation/candidate_comparison.csv")
  predictions <- data.frame(Id = te$Id, matchId = te$matchId, actual = te$winPlacePerc)
  for (nm in names(extended)) predictions[[nm]] <- as.numeric(predict(extended[[nm]], te))
  predictions$M2 <- as.numeric(predict(b$M2, te))
  predictions$M2_log1p <- as.numeric(predict(train_models$OLS_log1p$M2, log_te))
  predictions$M3_log1p <- as.numeric(predict(train_models$OLS_log1p$M3, log_te))
  predictions$M3_WLS_group <- as.numeric(predict(train_models$WLS_group$M3, te))
  csv_out(predictions, "05_validation/predictions_test.csv")
  match_mae <- combine(lapply(names(predictions)[-(1:3)], function(nm) {
    m <- tapply(abs(predictions[[nm]] - predictions$actual), predictions$matchId, mean)
    data.frame(model = nm, matchId = names(m), MAE = as.numeric(m))
  }))
  csv_out(match_mae, "05_validation/per_match_MAE.csv")
  pdf_out("01_M3_train_diagnostics.pdf", function() {
    par(mfrow = c(2, 2), mar = c(4, 4, 2, 1)); plot(b$M3, which = c(1, 2, 3, 5))
  })
  pdf_out("02_correlation_train.pdf", function() {
    C <- cor(tr[vars]); n <- ncol(C); par(mar = c(8, 8, 3, 2))
    image(seq_len(n), seq_len(n), C[, n:1], zlim = c(-1, 1),
      col = colorRampPalette(c("#2166AC", "white", "#B2182B"))(101),
      axes = FALSE, xlab = "", ylab = "", main = "Pearson correlations - training")
    axis(1, seq_len(n), colnames(C), las = 2, cex.axis = .8)
    axis(2, seq_len(n), rev(colnames(C)), las = 2, cex.axis = .8)
    for (i in seq_len(n)) for (j in seq_len(n))
      text(i, j, sprintf("%.2f", C[i, n + 1 - j]), cex = .8)
  })
  pdf_out("04_Cook_train.pdf", function() {
    cd <- cooks.distance(b$M3)
    plot(cd, type = "h", xlab = "Training row", ylab = "Cook distance")
    abline(h = 4 / nobs(b$M3), col = "red", lty = 2)
  })
  pdf_out("05_log1p_M3_train_diagnostics.pdf", function() {
    par(mfrow = c(2, 2), mar = c(4, 4, 2, 1)); plot(train_models$OLS_log1p$M3, which = c(1, 2, 3, 5))
  })
  pdf_out("06_quadratic_train_diagnostics.pdf", function() {
    par(mfrow = c(2, 2), mar = c(4, 4, 2, 1)); plot(extended$full_quadratic, which = c(1, 2, 3, 5))
  })
  pdf_out("07_heldout_errors.pdf", function() {
    par(mar = c(9, 4, 3, 1))
    barplot(candidates$RMSE, names.arg = candidates$model, las = 2,
      ylab = "Held-out RMSE", col = "#3A6EA5", main = "Existing holdout used for exploratory comparisons")
  })
  # 历史数值是核查目标而不是写入模型结果的常数。当前结果全部来自重新估计。
  reference <- data.frame(metric = c("full_raw_M3_R2", "train_raw_M3_R2", "full_raw_M3_kills",
    "full_raw_M3_cluster_SE_kills", "full_raw_H1_F", "full_raw_H2_F",
    "raw_M3_test_RMSE", "log1p_M3_test_RMSE", "quadratic_test_RMSE", "full_raw_H3_D"),
    expected = c(.713457303, .7102399692, -.0063935433264, .0024196463053,
      253.334409527, 2857.53957460, .154324583, .118187618, .152143304, .438033172))
  reference$actual <- c(summary(a$M3)$r.squared, summary(b$M3)$r.squared, coef(a$M3)["kills"],
    full_cluster$OLS_raw$cluster_se[full_cluster$OLS_raw$model == "M3" & full_cluster$OLS_raw$variable == "kills"],
    full_joint$OLS_raw$F, validation$OLS_raw$RMSE[validation$OLS_raw$model == "M3"],
    validation$OLS_log1p$RMSE[validation$OLS_log1p$model == "M3"],
    ext_val$RMSE[ext_val$model == "full_quadratic"], increments(a)$D)
  reference$absolute_difference <- abs(reference$actual - reference$expected)
  reference$tolerance <- 1e-6
  reference$within_tolerance <- reference$absolute_difference <= reference$tolerance
  csv_out(reference, "00_audit/historical_checks.csv")
  if (!all(reference$within_tolerance)) warning("部分历史对照超出容差；请查看historical_checks.csv。")

  # ==================== 8 模型 解释与可复现资料 ====================
  message("[7/8] 保存模型、统计日志及动态结果解读……")
  clean_models <- function(models) lapply(models, function(m) {
    # 数据列均在model.frame中；去除辅助公式对整个运行环境的捕获。
    environment(m$terms) <- baseenv()
    if (!is.null(m$model)) attr(m$model, "terms") <- m$terms
    if (inherits(m$call$formula, "formula")) environment(m$call$formula) <- baseenv()
    m
  })
  all_models <- lapply(all_models, clean_models)
  train_models <- lapply(train_models, clean_models)
  extended <- clean_models(extended); sensitive <- clean_models(sensitive)
  auxiliary <- clean_models(auxiliary); fwl <- clean_models(fwl)
  results <- list(input = input_file, input_md5 = hash, output_dir = normalizePath(out),
    full = all_models, train = train_models, extended = extended, sensitivity = sensitive,
    auxiliary = auxiliary, FWL = fwl, cluster_coefficients = full_cluster,
    joint_tests = full_joint, H3 = h3, bootstrap = boots, validation = validation,
    candidates = candidates, historical_checks = reference,
    parameters = list(bootstrap_B = bootstrap_B, seed = seed), session = sessionInfo())
  saveRDS(results, file.path(out, "07_models", "PUBG_integrated_models.rds"))
  writeLines(capture.output({
    cat("全样本模型 原尺度、log1p、组等权WLS\n")
    for (s in names(all_models)) for (nm in names(all_models[[s]])) {
      cat("\n", s, nm, "\n"); print(summary(all_models[[s]][[nm]]))
    }
    cat("\n训练集及拓展\n")
    for (nm in names(extended)) {cat("\n", nm, "\n"); print(summary(extended[[nm]]))}
    cat("\n敏感性\n"); lapply(sensitive, function(m) print(summary(m)))
    cat("\n辅助回归\n"); lapply(auxiliary, function(m) print(summary(m)))
  }), file.path(out, "PUBG_Regression_Results.txt"), useBytes = TRUE)
  raw_perf <- validation$OLS_raw
  m2v <- raw_perf[raw_perf$model == "M2", ]; m3v <- raw_perf[raw_perf$model == "M3", ]
  logv <- validation$OLS_log1p[validation$OLS_log1p$model == "M3", ]
  bv <- coef(a$M3)
  report <- c("IBA6101 PUBG 团队补充建模运行报告", meta,
    "", "一 分析原则",
    "全样本200场用于关联推断；160场训练用于探索与预测拟合，40场用于既有留出评价。",
    "聚类CR1参考t(G-1)和F(q,G-1)。H1与H2并列报告原始p值和同一规格内的Holm校正p值。",
    "常规嵌套F表用于探索性比较，正式H1与H2使用比赛聚类联合检验。",
    "组等权=每条记录1/同比赛同组记录数；log1p仅变换五个行为变量。",
    "", "二 主要回归与H1/H2", capture.output(print(fit_table(a), row.names = FALSE)),
    capture.output(print(full_joint$OLS_raw, row.names = FALSE)),
    "", "三 全样本原尺度系数的条件解读（其他变量固定）",
    sprintf("多1次击杀：拟合指标变化%+.6f，即%+.3f个指标百分点。", bv["kills"], 100 * bv["kills"]),
    sprintf("多100点伤害：变化%+.6f；多100米步行：变化%+.6f。", 100 * bv["damageDealt"], 100 * bv["walkDistance"]),
    sprintf("多用1次Boost：变化%+.6f；多用1次治疗：变化%+.6f。", bv["boosts"], bv["heals"]),
    "百分点是归一化名次指标的刻度，不是获胜概率或固定名次数，也不是因果收益。",
    "", "四 H3及敏感性", unlist(lapply(names(h3), function(s) c(s, capture.output(print(h3[[s]], row.names = FALSE))))),
    "正差值及区间若全高于0，支持本研究所选移动补给组的增量更大；两组变量个数不同。",
    "全样本bootstrap区间不可贴在训练集差值旁作为训练区间。",
    "", "五 系数变化与非线性",
    "见03_exploration：分别列出全样本单独加入、训练集顺序加入、训练集逐项删除。",
    "FWL和系数分解是同一OLS估计的代数关系，不能作为额外独立的因果证据。",
    "Cook阈值只筛候选，原始记录保留；敏感性模型不用于替换主样本。",
    "二次转折点是条件拟合曲线峰值，不能称作最优击杀策略。",
    "", "六 留出比较", capture.output(print(candidates, row.names = FALSE)),
    sprintf("原尺度M3 MAE=%.6f，即平均约%.2f个名次指标百分点。", m3v$MAE, 100 * m3v$MAE),
    sprintf("M2到M3的RMSE相对下降%.2f%%。", 100 * (m2v$RMSE - m3v$RMSE) / m2v$RMSE),
    sprintf("log1p M3相较原尺度M3的RMSE下降%.2f%%，MAE下降%.2f%%。",
      100 * (m3v$RMSE - logv$RMSE) / m3v$RMSE, 100 * (m3v$MAE - logv$MAE) / m3v$MAE),
    sprintf("log1p M3越界%d条（%.2f%%），预测未经截断。", logv$out_of_bounds_n, logv$out_of_bounds_pct),
    "所有留出误差均按记录等权计算，并另报按场平均MAE。组等权WLS的组权重用于模型拟合。",
    "", "七 限制与后续",
    "这是赛后行为关联分析，不能宣称实时/赛前预测或策略因果效果。",
    "当前留出集已用于多次候选比较，不是完全未参与选择的最终测试。",
    "本脚本没有执行按场交叉验证、外部新测试或误差差异显著性检验；这些仍是后续工作。",
    "重建bootstrap使用记录的种子和共享抽样；若历史随机流未保存，不保证逐次抽样与旧CSV一致。",
    "", "八 历史数值核对", capture.output(print(reference, row.names = FALSE)),
    "", "九 分析来源",
    "团队建模材料提供基础模型、留出比较及探索性诊断。聚类推断与bootstrap按项目统计协议重建。")
  writeLines(report, file.path(out, "6101_整合运行报告.txt"), useBytes = TRUE)
  files <- list.files(out, recursive = TRUE, full.names = TRUE)
  manifest <- data.frame(file = substring(files, nchar(out) + 2L),
    bytes = file.info(files)$size, MD5 = unname(tools::md5sum(files)))
  manifest <- manifest[manifest$file != "STATUS.txt", ]
  csv_out(manifest, "00_audit/output_manifest.csv")
  writeLines(c("COMPLETE", paste("完成时间", format(Sys.time(), tz = "Asia/Shanghai")),
    paste("历史对照全部通过", all(reference$within_tolerance))), file.path(out, "STATUS.txt"), useBytes = TRUE)
  finished <- TRUE
  message("[8/8] 完成。结果目录：", normalizePath(out))
  print(candidates, row.names = FALSE)
  invisible(results)
}

run_pubg_analysis(input_file, output_parent)
