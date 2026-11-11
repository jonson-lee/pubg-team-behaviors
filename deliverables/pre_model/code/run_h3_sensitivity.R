#!/usr/bin/env Rscript
# Run from any directory. An optional output directory supports isolated reruns.
file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
args <- commandArgs(trailingOnly = TRUE)
if (length(file_arg) != 1L || length(args) > 1L || any(!nzchar(args))) {
  stop("Usage: Rscript run_h3_sensitivity.R [output_directory]", call. = FALSE)
}
script_path <- normalizePath(gsub("~+~", " ", sub("^--file=", "", file_arg), fixed = TRUE))
project_dir <- dirname(dirname(script_path))
statistics_path <- file.path(project_dir, "code", "statistics.R")
source(statistics_path)
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required.")
options(stringsAsFactors = FALSE, digits = 17)

publish_results <- function(destination, tables, report, manifest) {
  parent <- dirname(destination)
  dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  stage <- tempfile(".h3-sensitivity-", tmpdir = parent)
  if (!dir.create(stage)) stop("Cannot stage the H3 sensitivity outputs.")
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  for (name in names(tables)) {
    write.csv(tables[[name]], file.path(stage, name), row.names = FALSE, na = "")
  }
  writeLines(report, file.path(stage, "H3_Sensitivity_Summary.md"), useBytes = TRUE)
  output_names <- list.files(stage)
  manifest$output_md5 <- as.list(setNames(tools::md5sum(file.path(stage, output_names)),
                                          output_names))
  jsonlite::write_json(manifest, file.path(stage, "run_manifest.json"),
                       auto_unbox = TRUE, pretty = TRUE, digits = NA)
  if (file.exists(destination)) {
    output_names <- list.files(stage)
    staged_hashes <- unname(tools::md5sum(file.path(stage, output_names)))
    existing_hashes <- unname(tools::md5sum(file.path(destination, output_names)))
    if (!identical(staged_hashes, existing_hashes)) {
      stop("The destination contains different results. Supply a new output directory.",
           call. = FALSE)
    }
    return(invisible(NULL))
  }
  if (!file.rename(stage, destination)) stop("Cannot publish the staged results.")
  invisible(NULL)
}

input_paths <- c(sample = file.path(project_dir, "data", "processed", "pubg_sample.csv"),
                 matches = file.path(project_dir, "data", "processed", "selected_matches.csv"))
expected_md5 <- c(sample = "c40153ed85bdc34afc0d99be24eaa740",
                  matches = "179fce68deb4572f276b7271b0bbac2a")
input_md5 <- setNames(tools::md5sum(input_paths), names(input_paths))
if (!identical(input_md5, expected_md5)) {
  stop("Expected the fixed PUBG sample and selected match list. Check input checksums.",
       call. = FALSE)
}
dat <- read.csv(input_paths[["sample"]])
stopifnot(nrow(dat) == 18935L, length(unique(dat$matchId)) == 200L,
          all(dat$matchType == "solo-fpp"))
seed <- 6103L
reps <- 1000L
specifications <- expand.grid(combat_variable = c("kills", "damageDealt"),
                              transform = c("raw", "log1p"), stringsAsFactors = FALSE)

fit_specification <- function(combat_variable, transform) {
  models <- fit_models(dat, transform = transform, combat_variables = combat_variable)
  comparison <- model_comparison(models, dat, combat_variables = combat_variable)
  boot <- bootstrap_h3(dat, reps = reps, seed = seed, transform = transform,
                       combat_variables = combat_variable)
  inference <- cluster_inference(models$full, dat$matchId, combat_variables = combat_variable)
  stopifnot(identical(inference$joint_tests$df_num, c(1L, 3L)),
            isTRUE(all.equal(boot$estimate, comparison$h3$D, tolerance = 1e-10)))
  design <- model.matrix(models$full)[, -1L, drop = FALSE]
  vif <- diag(solve(cor(design)))
  r2 <- setNames(comparison$metrics$r_squared, comparison$metrics$model)
  tags <- data.frame(combat_variable = combat_variable, transform = transform)
  coefficients <- inference$coefficients
  coefficients$VIF <- unname(vif[coefficients$term])
  tests <- inference$joint_tests
  tests$p_holm <- p.adjust(tests$p_value, method = "holm")
  list(
    summary = cbind(tags, data.frame(n_records = nrow(dat), n_matches = boot$metadata$matches_per_draw,
      r2_context = r2[["context"]], r2_combat = r2[["combat"]],
      r2_mobility = r2[["mobility"]], r2_full = r2[["full"]]), comparison$h3,
      data.frame(ci_low = boot$ci_low, ci_high = boot$ci_high, max_VIF = max(vif),
                 repetitions = boot$reps, seed = boot$seed)),
    draws = cbind(tags, boot$draws),
    coefficients = cbind(tags, coefficients),
    tests = cbind(tags, tests)
  )
}

results <- Map(fit_specification, specifications$combat_variable, specifications$transform)
bind_results <- function(field) do.call(rbind, lapply(results, `[[`, field))
summary <- bind_results("summary")
tables <- list("h3_sensitivity.csv" = summary, "bootstrap_draws.csv" = bind_results("draws"),
               "coefficients_clustered.csv" = bind_results("coefficients"),
               "joint_tests_clustered.csv" = bind_results("tests"))

fmt <- function(x) sprintf("%.6f", x)
table_lines <- with(summary, sprintf("| `%s` | %s | %s | %s | %s | [%s, %s] | %.3f |",
  combat_variable, ifelse(transform == "raw", "原尺度", "`log1p`"), fmt(delta_combat),
  fmt(delta_mobility), fmt(D), fmt(ci_low), fmt(ci_high), max_VIF))
conclusion <- if (all(summary$ci_low > 0)) {
  "四个区间均高于零。在这些全样本补充规格中，移动恢复组的条件解释增量均大于单一战斗指标。"
} else {
  "逐行比较区间与零的位置。跨零的区间无法确定该规格下解释增量的顺序。"
}
report <- c(
  "# H3 单一战斗指标敏感性分析", "",
  "2026-11-11 · PUBG Solo-FPP 固定样本，200 场比赛、18,935 条记录。", "",
  conclusion, "",
  "| 保留的战斗指标 | 尺度 | 战斗增量 R² | 移动恢复增量 R² | 差值 D | 整场 bootstrap 95% 区间 | 最大 VIF |",
  "| --- | --- | ---: | ---: | ---: | --- | ---: |", table_lines, "",
  "四个规格均使用 OLS，控制 `numGroups`，移动恢复组保留 `walkDistance`、`boosts` 和 `heals`。`log1p` 作用于保留的战斗变量和三个移动恢复变量，响应和比赛组数采用原尺度。", "",
  "战斗增量为完整模型 R² 减去只含上下文和移动恢复的模型 R²。移动恢复增量为完整模型 R² 减去只含上下文和战斗的模型 R²。D 为移动恢复增量减战斗增量，因此等于两个简化模型的 R² 之差。", "",
  "每个规格使用相同的 1,000 次比赛重抽样（种子 `6103`），每次有放回抽取 200 场并按抽中次数保留整场记录。区间为逐规格的双侧 95% 百分位区间（R quantile type 7）。", "",
  "这些事后敏感性结果比较三项移动恢复变量与一个战斗代表指标的赛后关联。两个变量组的规模不同，推断范围限于指定指标与样本。", "",
  "[结果 CSV](h3_sensitivity.csv)含四模型 R² 和两组解释增量。[抽样明细](bootstrap_draws.csv)记录每轮 D 与抽样数量。[系数与 VIF](coefficients_clustered.csv)和[聚类检验](joint_tests_clustered.csv)采用比赛聚类 CR1，战斗与移动恢复组的检验分别有一项与三项限制。Holm 校正限于各规格的两项检验。", "",
  "从课程目录运行 `Rscript --vanilla Project/code/run_h3_sensitivity.R` 复现。可用一个可选参数指定新的输出目录。[运行清单](run_manifest.json)记录输入、代码和结果校验值。"
)
tracked_code <- c(statistics = statistics_path, entry_point = script_path)
manifest <- list(
  analysis_date = "2026-11-11", timezone = "Asia/Shanghai", R_version = R.version.string,
  inputs_md5 = as.list(input_md5), code_md5 = as.list(setNames(tools::md5sum(tracked_code),
                                                             names(tracked_code))),
  n_records = nrow(dat), n_matches = length(unique(dat$matchId)),
  repetitions = reps, seed = seed, rng = "Mersenne-Twister / Inversion / Rejection",
  estimand = "D = delta_mobility - delta_combat = R2_mobility - R2_combat",
  interval = "Paired whole-match bootstrap, pointwise two-sided 95% percentile, quantile type 7",
  specifications = specifications
)
destination <- if (length(args)) args[[1L]] else
  file.path(project_dir, "reports", "analysis", "h3-sensitivity-2026-11-11")
publish_results(destination, tables, report, manifest)
print(summary[c("combat_variable", "transform", "delta_combat", "delta_mobility", "D",
                "ci_low", "ci_high", "max_VIF")], row.names = FALSE, digits = 7)
