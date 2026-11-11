# Run manually once if car or corrplot is not installed.
packages <- c("car", "corrplot")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  install.packages(missing, repos = "https://cloud.r-project.org")
} else {
  message("Required packages are already installed.")
}
