# Reconstructed from the saved November 7 R history.
# Uses the existing train/test split and leaves archived results untouched.
options(width = 120, stringsAsFactors = FALSE)

required_packages <- c("car", "corrplot")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Missing packages: ", paste(missing_packages, collapse = ", "),
       ". Run scripts/setup.R first.")
}

args <- commandArgs(trailingOnly = TRUE)
script_arg <- grep("^--file=", commandArgs(), value = TRUE)
source_files <- vapply(sys.frames(), function(frame) {
  if (is.null(frame$ofile)) "" else as.character(frame$ofile)[1]
}, character(1))
source_files <- source_files[nzchar(source_files)]
entry_file <- if (length(source_files)) {
  tail(source_files, 1)
} else if (length(script_arg)) {
  sub("^--file=", "", script_arg[1])
} else {
  ""
}
root <- if (nzchar(entry_file)) {
  dirname(dirname(normalizePath(entry_file, mustWork = TRUE)))
} else {
  getwd()
}
input <- file.path(root, "data", "pubg_sample.csv")
if (!file.exists(input)) stop("Open the project first; data/pubg_sample.csv was not found.")
output <- if (length(args)) args[1] else file.path(root, "results", "reproduced")
for (folder in c(output, file.path(output, "details"), file.path(output, "figures"), file.path(output, "models"))) {
  dir.create(folder, recursive = TRUE, showWarnings = FALSE)
}

df <- read.csv(input, check.names = FALSE)
variables <- c("numGroups", "kills", "damageDealt", "walkDistance", "boosts", "heals")
needed <- c("winPlacePerc", variables, "split")
if (!all(needed %in% names(df))) stop("Required columns are missing from the data.")
if (anyNA(df[needed]) || !all(df$split %in% c("train", "test"))) {
  stop("Analysis columns contain missing values or unrecognized split labels.")
}
if (!all(vapply(df[c("winPlacePerc", variables)], is.numeric, logical(1)))) {
  stop("Outcome and predictors must be numeric.")
}
if (!all(vapply(df[c("winPlacePerc", variables)], function(x) all(is.finite(x)), logical(1)))) {
  stop("Outcome and predictors must contain finite values.")
}
train_df <- df[df$split == "train", , drop = FALSE]
test_df <- df[df$split == "test", , drop = FALSE]
if (!nrow(train_df) || !nrow(test_df)) stop("Both train and test data are required.")

m0 <- lm(winPlacePerc ~ numGroups, data = train_df)
m1 <- lm(winPlacePerc ~ numGroups + kills + damageDealt, data = train_df)
m2 <- lm(winPlacePerc ~ numGroups + walkDistance + boosts + heals, data = train_df)
m3 <- lm(winPlacePerc ~ numGroups + kills + damageDealt + walkDistance + boosts + heals, data = train_df)
m_no_damage <- update(m3, . ~ . - damageDealt)
m_no_kills <- update(m3, . ~ . - kills)
step1 <- update(m1, . ~ . + walkDistance)
step2 <- update(step1, . ~ . + boosts)
step3 <- update(step2, . ~ . + heals)
aux_model <- lm(damageDealt ~ kills + numGroups + walkDistance + boosts + heals, data = train_df)

cd <- cooks.distance(m3)
m3_sensitivity <- lm(formula(m3), data = train_df[cd <= 4 / nrow(train_df), , drop = FALSE])
m3_quadratic <- update(m3, . ~ . + I(kills^2))
m_kills_quadratic <- update(m_no_damage, . ~ . + I(kills^2))
cd_quad <- cooks.distance(m3_quadratic)
m3_quad_sensitivity <- lm(formula(m3_quadratic),
                          data = train_df[cd_quad <= 4 / nobs(m3_quadratic), , drop = FALSE])

all_models <- list(m0 = m0, m1 = m1, m2 = m2, m3 = m3,
                   m_no_damage = m_no_damage, m_no_kills = m_no_kills,
                   m_kills_quadratic = m_kills_quadratic, m3_quadratic = m3_quadratic,
                   m3_sensitivity = m3_sensitivity, m3_quad_sensitivity = m3_quad_sensitivity,
                   step1 = step1, step2 = step2, step3 = step3, aux_model = aux_model)
write_detail <- function(name, object) {
  writeLines(capture.output(print(object)), file.path(output, "details", paste0(name, ".txt")))
}
for (name in names(all_models)) write_detail(name, summary(all_models[[name]]))
comparisons <- list(c("m0", "m1"), c("m0", "m2"), c("m0", "m3"),
                    c("m1", "m3"), c("m2", "m3"), c("m_no_damage", "m3"),
                    c("m_no_kills", "m3"), c("m3", "m3_quadratic"),
                    c("m_no_damage", "m_kills_quadratic"),
                    c("m_no_kills", "m3_quadratic"), c("m_kills_quadratic", "m3_quadratic"))
for (pair in comparisons) {
  write_detail(paste0("anova_", pair[1], "_vs_", pair[2]),
               anova(all_models[[pair[1]]], all_models[[pair[2]]]))
}
for (name in c("m1", "m3", "m_no_damage", "m_no_kills")) {
  write_detail(paste0("VIF_", name), car::vif(all_models[[name]]))
}
write_detail("drop1_m3", drop1(m3, test = "F"))
cor_matrix <- cor(train_df[c("kills", "damageDealt", "walkDistance", "boosts", "heals", "numGroups", "winPlacePerc")],
                  method = "pearson", use = "complete.obs")
write_detail("Pearson_Correlation", round(cor_matrix, 3))

deletion_models <- list("Full Model (m3)" = m3,
                       "Without walkDistance" = update(m3, . ~ . - walkDistance),
                       "Without boosts" = update(m3, . ~ . - boosts),
                       "Without heals" = update(m3, . ~ . - heals),
                       "Without damageDealt" = m_no_damage)
kills_comparison <- do.call(rbind, lapply(names(deletion_models), function(name) {
  x <- summary(deletion_models[[name]])$coefficients["kills", ]
  data.frame(Model = name, Coefficient = unname(x[1]), Std_Error = unname(x[2]), P_value = unname(x[4]))
}))
kills_comparison$Significance <- with(kills_comparison,
                                      ifelse(P_value < .001, "***", ifelse(P_value < .01, "**", ifelse(P_value < .05, "*", ""))))
kills_comparison$Coefficient_Star <- paste0(sprintf("%.6f", kills_comparison$Coefficient), kills_comparison$Significance)
write_detail("Kills_Coefficient_Comparison", kills_comparison)

models <- list(m3 = m3, m_no_damage = m_no_damage, m_no_kills = m_no_kills,
               m_kills_quadratic = m_kills_quadratic, m3_quadratic = m3_quadratic)
test_results <- do.call(rbind, lapply(names(models), function(name) {
  pred <- predict(models[[name]], newdata = test_df)
  actual <- test_df$winPlacePerc
  valid <- is.finite(pred) & is.finite(actual)
  data.frame(Model = name, N = sum(valid),
             RMSE = sqrt(mean((actual[valid] - pred[valid])^2)),
             MAE = mean(abs(actual[valid] - pred[valid])),
             Test_R2 = 1 - sum((actual[valid] - pred[valid])^2) / sum((actual[valid] - mean(actual[valid]))^2),
             Out_of_Range = sum(pred[valid] < 0 | pred[valid] > 1))
}))
test_results <- test_results[order(test_results$RMSE), ]
rownames(test_results) <- NULL
write.csv(test_results, file.path(output, "Model_Comparison.csv"), row.names = FALSE)
write_detail("Test_Results", test_results)
saveRDS(models, file.path(output, "models", "PUBG_Models.rds"))

summary_lines <- capture.output({
  cat("=== Original Models ===\n\n")
  for (name in c("m0", "m1", "m2", "m3")) print(summary(all_models[[name]]))
  cat("\n=== Extended Models ===\n\n")
  for (name in c("m_no_damage", "m_no_kills", "m_kills_quadratic", "m3_quadratic")) print(summary(all_models[[name]]))
  cat("\n=== ANOVA ===\n\n")
  for (pair in comparisons) {
    cat(pair[1], "vs", pair[2], "\n")
    print(anova(all_models[[pair[1]]], all_models[[pair[2]]]))
  }
  cat("\n=== Correlation Matrix ===\n\n")
  print(round(cor_matrix, 3))
  cat("\n=== VIF ===\n\n")
  for (name in c("m1", "m3", "m_no_damage", "m_no_kills")) {
    cat(name, "\n")
    print(car::vif(all_models[[name]]))
  }
  cat("\n=== Auxiliary Regression ===\n\n")
  print(summary(aux_model))
  cat("\n=== Test Results ===\n\n")
  print(test_results, row.names = FALSE)
})
writeLines(summary_lines, file.path(output, "PUBG_Regression_Results.txt"))
writeLines(capture.output(sessionInfo()), file.path(output, "Session_Info.txt"))

rx <- resid(lm(kills ~ numGroups + damageDealt + walkDistance + boosts + heals, data = train_df))
ry <- resid(lm(winPlacePerc ~ numGroups + damageDealt + walkDistance + boosts + heals, data = train_df))
diagnostics <- capture.output({
  cat("Train:", nrow(train_df), "Test:", nrow(test_df), "\n")
  cat("m3 Cook's distance above 4/n:", sum(cd > 4 / nrow(train_df)), "\n")
  cat("m3 quadratic Cook's distance above 4/n:", sum(cd_quad > 4 / nobs(m3_quadratic)), "\n")
  cat("\nCoefficient decomposition\n")
  print(c(Actual = coef(m_no_damage)[["kills"]],
          Decomposed = coef(m3)[["kills"]] + coef(m3)[["damageDealt"]] * coef(aux_model)[["kills"]]))
  cat("\nPartial regression slope\n")
  print(coef(lm(ry ~ rx)))
  cat("\nKills quantiles\n")
  print(quantile(train_df$kills, c(0, .25, .5, .75, .9, .95, .99, 1)))
})
writeLines(diagnostics, file.path(output, "Diagnostics.txt"))

save_plot <- function(name, draw) {
  png(file.path(output, "figures", name), width = 1600, height = 1200, res = 160)
  on.exit(dev.off(), add = TRUE)
  draw()
}
save_plot("partial_regression_kills.png", function() {
  plot(rx, ry, pch = 16, cex = .35, col = rgb(0, 0, 0, .15),
       xlab = "Residualized kills", ylab = "Residualized winPlacePerc", main = "Partial Regression Plot: kills")
  abline(lm(ry ~ rx), col = "red", lwd = 2)
})
save_plot("cooks_distance_m3.png", function() {
  plot(cd, type = "h", main = "Cook's Distance - m3", ylab = "Cook's Distance")
  abline(h = 4 / nrow(train_df), col = "red", lty = 2)
})
save_plot("pearson_correlation.png", function() {
  corrplot::corrplot(cor_matrix, method = "color", type = "upper", diag = TRUE, order = "original",
                     col = colorRampPalette(c("#0033FF", "#FFFFFF", "#FF2600"))(200),
                     col.lim = c(-1, 1), cl.pos = "r", cl.cex = .85,
                     addCoef.col = "black", number.cex = .85, number.digits = 2,
                     tl.col = "black", tl.cex = 1, tl.srt = 90, tl.pos = "td",
                     addgrid.col = NA, mar = c(0, 0, 1, 0))
})
message("Analysis complete. Results: ", normalizePath(output))
