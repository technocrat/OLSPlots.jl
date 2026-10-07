# Run from the repository root:
# Rscript --vanilla examples/compare_with_r.R /tmp/olsplots-comparison
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Supply an output directory as the only argument.")
output_dir <- args[[1L]]
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

cars <- read.csv("data/mtcars.csv", stringsAsFactors = FALSE)
stopifnot(identical(cars$model, rownames(datasets::mtcars)))
for (column in names(cars)[-1L]) {
    stopifnot(isTRUE(all.equal(cars[[column]], datasets::mtcars[[column]])))
}
rownames(cars) <- cars$model
fit <- lm(mpg ~ hp + drat + wt, data = cars)
diagnostics <- data.frame(
    model = cars$model,
    fitted = fitted(fit),
    residual = residuals(fit),
    leverage = hatvalues(fit),
    standardized_residual = rstandard(fit),
    cooks_distance = cooks.distance(fit),
    row.names = NULL
)
write.csv(diagnostics, file.path(output_dir, "mtcars-r-diagnostics.csv"),
          row.names = FALSE)

pdf(file.path(output_dir, "mtcars-r.pdf"), width = 10, height = 15)
par(mfrow = c(3, 2))
plot(fit, which = 1:6, ask = FALSE)
invisible(dev.off())
cat(R.version.string, "\n")
cat("Model: mpg ~ hp + drat + wt (intercept included, unweighted)\n")
cat("R diagnostics and six-panel PDF written to:", output_dir, "\n")
