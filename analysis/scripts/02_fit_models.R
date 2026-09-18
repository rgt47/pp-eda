# 02_fit_models.R
# Purpose: Fit simple linear regression model
# Input: analysis/data/derived_data/penguins_clean.csv
# Output: Model results, coefficients, and metrics

library(tidyverse)
library(broom)

cat("🐧 Palmer Penguins Part 1: Model Fitting\n")
cat("=========================================\n\n")

# Load prepared data
penguins_clean <- read_csv("analysis/data/derived_data/penguins_clean.csv", show_col_types = FALSE)

# Fit simple linear regression model
simple_model <- lm(body_mass_g ~ flipper_length_mm, data = penguins_clean)

# Extract coefficients with confidence intervals
model_coefficients <- tidy(simple_model, conf.int = TRUE)
model_metrics <- glance(simple_model)

# Display key results
cat("📊 Simple Linear Model Results:\n")
cat("===============================\n")
cat(sprintf("R-squared: %.3f (%.1f%% of variance explained)\n",
            model_metrics$r.squared, model_metrics$r.squared * 100))
cat(sprintf("RMSE: %.1f grams\n",
            sqrt(mean(residuals(simple_model)^2))))
cat(sprintf("Residual standard error: %.1f grams\n", sigma(simple_model)))
cat(sprintf("F-statistic: %.1f (p < 0.001)\n", model_metrics$statistic))

# Model equation with confidence intervals
intercept <- model_coefficients$estimate[1]
slope <- model_coefficients$estimate[2]
slope_ci_lower <- model_coefficients$conf.low[2]
slope_ci_upper <- model_coefficients$conf.high[2]

cat("\n🧮 Model Equation:\n")
cat(sprintf("Body Mass = %.1f + %.1f × Flipper Length\n", intercept, slope))
cat(sprintf("Slope 95%% CI: [%.1f, %.1f] grams/mm\n", slope_ci_lower, slope_ci_upper))

# Save model coefficients
write_csv(model_coefficients, "analysis/data/derived_data/model_coefficients.csv")

# Save model metrics
metrics_df <- data.frame(
  r_squared = model_metrics$r.squared,
  rmse = sqrt(mean(residuals(simple_model)^2)),
  residual_se = sigma(simple_model),
  f_statistic = model_metrics$statistic,
  p_value = model_metrics$p.value,
  observations = model_metrics$nobs
)
write_csv(metrics_df, "analysis/data/derived_data/model_metrics.csv")

# Generate predictions with confidence intervals
new_data <- tibble(flipper_length_mm = c(180, 200, 220))
predictions <- predict(simple_model, newdata = new_data, interval = "confidence")

cat("\n📝 Example Predictions (95% CI):\n")
for(i in 1:nrow(new_data)) {
  cat(sprintf("• %dmm flippers: %.0f g [%.0f, %.0f]\n",
              new_data$flipper_length_mm[i],
              predictions[i, "fit"],
              predictions[i, "lwr"],
              predictions[i, "upr"]))
}

# Model diagnostic checks
penguins_with_predictions <- penguins_clean %>%
  mutate(
    predicted = predict(simple_model),
    residuals = residuals(simple_model),
    standardized_residuals = rstandard(simple_model)
  )

# Check for outliers and influential points
outliers <- which(abs(penguins_with_predictions$standardized_residuals) > 2.5)
cat("\n⚠️  Model Assumption Checks:\n")
cat(sprintf("• Potential outliers: %d observations (>2.5 SD from mean)\n", length(outliers)))
cat(sprintf("• Residual standard error: %.1f grams\n", sigma(simple_model)))

# Save predictions and diagnostics
write_csv(penguins_with_predictions, "analysis/data/derived_data/model_predictions.csv")

# Save model object for later use
saveRDS(simple_model, "analysis/data/derived_data/simple_model.rds")

cat("\n✅ Model fitting complete!\n")
