# The committed derived files are what the report reads, so check that
# they agree with the source data and with a fresh model fit.

derived_dir <- here::here('analysis', 'data', 'derived_data')
derived_files <- c(
  'penguins_clean.csv', 'species_summary.csv', 'correlation_matrix.csv',
  'model_coefficients.csv', 'model_metrics.csv', 'model_predictions.csv',
  'simple_model.rds'
)

for (f in derived_files) {
  expect_true(
    file.exists(file.path(derived_dir, f)),
    info = paste('derived file exists:', f)
  )
}

penguins_clean <- read.csv(file.path(derived_dir, 'penguins_clean.csv'))
source_clean <- palmerpenguins::penguins |>
  as.data.frame() |>
  na.omit()

expect_equal(
  nrow(penguins_clean), nrow(source_clean),
  info = 'penguins_clean has one row per complete case'
)
expect_false(anyNA(penguins_clean), info = 'penguins_clean has no NA')
expect_equal(
  penguins_clean$body_mass_g, as.numeric(source_clean$body_mass_g),
  info = 'penguins_clean body mass matches the source data'
)

species_summary <- read.csv(file.path(derived_dir, 'species_summary.csv'))
expect_equal(
  sum(species_summary$n), nrow(penguins_clean),
  info = 'species counts sum to the cleaned sample size'
)
expect_equal(
  sum(species_summary$percentage), 100, tolerance = 0.002,
  info = 'species percentages sum to 100 within rounding'
)

refit <- lm(body_mass_g ~ flipper_length_mm, data = penguins_clean)

coefs <- read.csv(file.path(derived_dir, 'model_coefficients.csv'))
expect_equal(
  coefs$estimate, unname(coef(refit)),
  info = 'saved coefficients match a refit'
)
expect_equal(
  coefs$conf.low, unname(confint(refit)[, 1]),
  info = 'saved lower CI matches a refit'
)

metrics <- read.csv(file.path(derived_dir, 'model_metrics.csv'))
expect_equal(
  metrics$r_squared, summary(refit)$r.squared,
  info = 'saved R-squared matches a refit'
)
expect_equal(
  metrics$rmse, sqrt(mean(residuals(refit)^2)),
  info = 'saved RMSE matches a refit'
)
expect_equal(
  metrics$residual_se, sigma(refit),
  info = 'saved residual SE matches a refit'
)
expect_equal(
  metrics$observations, nobs(refit),
  info = 'saved n matches a refit'
)

saved_model <- readRDS(file.path(derived_dir, 'simple_model.rds'))
expect_inherits(saved_model, 'lm', info = 'saved model is an lm')
expect_equal(
  unname(coef(saved_model)), unname(coef(refit)),
  info = 'saved model coefficients match a refit'
)

# The report renders from its own copy of the derived data, which goes
# stale silently if it is not refreshed after the scripts are rerun.
report_dir <- here::here('analysis', 'report', 'data', 'derived_data')
for (f in derived_files) {
  expect_equal(
    unname(tools::md5sum(file.path(report_dir, f))),
    unname(tools::md5sum(file.path(derived_dir, f))),
    info = paste('report copy is current:', f)
  )
}
