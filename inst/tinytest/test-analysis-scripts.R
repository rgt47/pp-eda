# Integration test: run the three analysis scripts end to end.
# The scripts write to fixed paths relative to the project root, so they
# run in a temporary copy to leave the committed outputs untouched.

required <- c('tidyverse', 'palmerpenguins', 'broom', 'corrplot', 'patchwork')
missing <- required[!vapply(required, requireNamespace, logical(1),
  quietly = TRUE)]
if (length(missing) > 0) {
  exit_file(paste('missing packages:', paste(missing, collapse = ', ')))
}

scripts <- c(
  '01_prepare_data.R', '02_fit_models.R', '03_generate_figures.R'
)
script_dir <- here::here('analysis', 'scripts')

for (s in scripts) {
  path <- file.path(script_dir, s)
  expect_true(file.exists(path), info = paste('script exists:', s))
  expect_false(
    inherits(try(parse(path), silent = TRUE), 'try-error'),
    info = paste('script parses:', s)
  )
}

sandbox <- file.path(tempfile('pp-eda-'), 'project')
dir.create(file.path(sandbox, 'analysis', 'scripts'), recursive = TRUE)
dir.create(file.path(sandbox, 'analysis', 'data', 'derived_data'),
  recursive = TRUE)
dir.create(file.path(sandbox, 'analysis', 'figures'))
file.copy(file.path(script_dir, scripts),
  file.path(sandbox, 'analysis', 'scripts'))

old_wd <- setwd(sandbox)
run_ok <- vapply(scripts, function(s) {
  res <- try(
    suppressMessages(suppressWarnings(utils::capture.output(
      source(file.path('analysis', 'scripts', s), local = new.env())
    ))),
    silent = TRUE
  )
  !inherits(res, 'try-error')
}, logical(1))
setwd(old_wd)

for (s in scripts) {
  expect_true(run_ok[[s]], info = paste('script runs without error:', s))
}

new_dir <- file.path(sandbox, 'analysis', 'data', 'derived_data')
committed_dir <- here::here('analysis', 'data', 'derived_data')

expect_equal(
  read.csv(file.path(new_dir, 'penguins_clean.csv')),
  read.csv(file.path(committed_dir, 'penguins_clean.csv')),
  info = 'rerun reproduces committed penguins_clean.csv'
)
expect_equal(
  read.csv(file.path(new_dir, 'model_coefficients.csv')),
  read.csv(file.path(committed_dir, 'model_coefficients.csv')),
  info = 'rerun reproduces committed model_coefficients.csv'
)
expect_equal(
  read.csv(file.path(new_dir, 'model_metrics.csv')),
  read.csv(file.path(committed_dir, 'model_metrics.csv')),
  info = 'rerun reproduces committed model_metrics.csv'
)

figures <- c(
  'eda-overview.png', 'species-comparison.png', 'correlation-matrix.png',
  'simple-regression-model.png', 'model-diagnostics.png'
)
for (f in figures) {
  fig <- file.path(sandbox, 'analysis', 'figures', f)
  expect_true(
    file.exists(fig) && file.size(fig) > 0,
    info = paste('figure generated:', f)
  )
}

unlink(dirname(sandbox), recursive = TRUE)
