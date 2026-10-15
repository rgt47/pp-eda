# Integration test: source data and the cleaning rule used by
# 01_prepare_data.R, independent of the saved derived files.

penguins <- palmerpenguins::penguins

expect_true(nrow(penguins) > 0, info = 'penguins has rows')
expect_true(ncol(penguins) >= 7, info = 'penguins has >= 7 columns')
expect_true(
  all(c('bill_length_mm', 'flipper_length_mm', 'body_mass_g') %in%
    names(penguins)),
  info = 'penguins has the analysis columns'
)

clean_penguins <- penguins[complete.cases(penguins), ]
expect_true(nrow(clean_penguins) > 0, info = 'complete cases remain')
expect_true(
  nrow(clean_penguins) <= nrow(penguins),
  info = 'cleaning does not add rows'
)

model <- lm(body_mass_g ~ flipper_length_mm, data = clean_penguins)
expect_inherits(model, 'lm', info = 'simple model is an lm')
expect_equal(length(coef(model)), 2L, info = 'intercept and slope')
expect_true(
  summary(model)$r.squared > 0,
  info = 'model explains some variance'
)

expected_species <- c('Adelie', 'Chinstrap', 'Gentoo')
expect_true(
  all(unique(as.character(penguins$species)) %in% expected_species),
  info = 'only the three expected species'
)

bill <- penguins$bill_length_mm[!is.na(penguins$bill_length_mm)]
expect_true(all(bill > 0 & bill < 100), info = 'bill length in (0, 100) mm')

mass <- penguins$body_mass_g[!is.na(penguins$body_mass_g)]
expect_true(all(mass > 0 & mass < 10000), info = 'body mass in (0, 10000) g')
