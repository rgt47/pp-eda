# 03_generate_figures.R
# Purpose: Generate publication-quality figures for the blog post
# Input: analysis/data/derived_data/{penguins_clean.csv, model_predictions.csv, simple_model.rds}
# Output: analysis/figures/{*.png}

library(tidyverse)
library(corrplot)
library(ggplot2)
library(patchwork)

cat("🐧 Palmer Penguins Part 1: Figure Generation\n")
cat("============================================\n\n")

# Set theme for consistent plotting
theme_set(theme_minimal(base_size = 12))

# Set penguin-friendly colors
penguin_colors <- c("Adelie" = "#FF6B6B", "Chinstrap" = "#9B59B6", "Gentoo" = "#2E86AB")

# Load prepared data and model
penguins_clean <- read_csv("analysis/data/derived_data/penguins_clean.csv", show_col_types = FALSE)
simple_model <- readRDS("analysis/data/derived_data/simple_model.rds")
penguins_with_predictions <- read_csv("analysis/data/derived_data/model_predictions.csv", show_col_types = FALSE)

# ============================================================================
# Figure 1: EDA Overview (Species and Relationships)
# ============================================================================
cat("Generating Figure 1: EDA Overview...\n")

species_summary <- penguins_clean %>%
  group_by(species) %>%
  summarise(
    n = n(),
    body_mass_mean = round(mean(body_mass_g), 0),
    flipper_length_mean = round(mean(flipper_length_mm), 1),
    .groups = "drop"
  ) %>%
  mutate(percentage = round(n / sum(n) * 100, 1))

p_species <- ggplot(species_summary, aes(x = species, y = n, fill = species)) +
  geom_col(alpha = 0.8) +
  geom_text(aes(label = paste0(n, "\n(", percentage, "%)")),
            vjust = -0.5, size = 3.5) +
  scale_fill_manual(values = penguin_colors) +
  # Headroom so the tallest bar's two-line label is not clipped
  scale_y_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title = "Species Distribution", x = "Species", y = "Count") +
  theme_minimal() + theme(legend.position = "none")

p_relationship <- ggplot(penguins_clean, aes(x = flipper_length_mm, y = body_mass_g, color = species)) +
  geom_point(alpha = 0.7, size = 1.5) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 0.8) +
  scale_color_manual(values = penguin_colors) +
  labs(title = "Flipper Length vs Body Mass",
       x = "Flipper Length (mm)", y = "Body Mass (g)", color = "Species") +
  theme_minimal()

eda_overview <- p_species + p_relationship
ggsave("analysis/figures/eda-overview.png", plot = eda_overview, width = 10, height = 5, dpi = 300)
cat("  ✅ Saved: analysis/figures/eda-overview.png\n")

# ============================================================================
# Figure 2: Species Comparison (Body Mass Distribution)
# ============================================================================
cat("Generating Figure 2: Species Comparison...\n")

p_comparison <- ggplot(penguins_clean, aes(x = species, fill = species)) +
  geom_boxplot(aes(y = body_mass_g), alpha = 0.7, position = position_dodge(0.8)) +
  scale_fill_manual(values = penguin_colors) +
  labs(title = "Body Mass Distribution by Species",
       subtitle = "Gentoo penguins are notably larger than Adelie and Chinstrap",
       x = "Species", y = "Body Mass (g)") +
  theme_minimal() + theme(legend.position = "none")

ggsave("analysis/figures/species-comparison.png", plot = p_comparison, width = 8, height = 5, dpi = 300)
cat("  ✅ Saved: analysis/figures/species-comparison.png\n")

# ============================================================================
# Figure 3: Correlation Matrix
# ============================================================================
cat("Generating Figure 3: Correlation Matrix...\n")

numeric_vars <- penguins_clean %>%
  select(bill_length_mm, bill_depth_mm, flipper_length_mm, body_mass_g)

correlation_matrix <- cor(numeric_vars)

png("analysis/figures/correlation-matrix.png", width = 6, height = 6, res = 300, units = "in")
corrplot(correlation_matrix, method = "color", type = "upper",
         order = "hclust", tl.cex = 1.0, tl.col = "black",
         addCoef.col = "black", number.cex = 0.8,
         title = "Morphometric Correlations", mar = c(0,0,2,0))
dev.off()
cat("  ✅ Saved: analysis/figures/correlation-matrix.png\n")

# ============================================================================
# Figure 4: Simple Linear Regression Model
# ============================================================================
cat("Generating Figure 4: Simple Linear Regression Model...\n")

model_plot <- ggplot(penguins_clean, aes(x = flipper_length_mm, y = body_mass_g)) +
  geom_point(aes(color = species), alpha = 0.6) +
  geom_smooth(method = "lm", color = "black", fill = "gray80") +
  scale_color_manual(values = penguin_colors) +
  labs(title = "Simple Linear Regression: Body Mass ~ Flipper Length",
       subtitle = "Gray band shows 95% confidence interval",
       x = "Flipper Length (mm)", y = "Body Mass (g)", color = "Species") +
  theme_minimal()

ggsave("analysis/figures/simple-regression-model.png", plot = model_plot, width = 8, height = 5, dpi = 300)
cat("  ✅ Saved: analysis/figures/simple-regression-model.png\n")

# ============================================================================
# Figure 5: Model Diagnostics
# ============================================================================
cat("Generating Figure 5: Model Diagnostics...\n")

diagnostic_plot <- ggplot(penguins_with_predictions, aes(x = predicted, y = standardized_residuals)) +
  geom_point(aes(color = species), alpha = 0.6) +
  geom_hline(yintercept = c(-2, 0, 2), linetype = c("dashed", "solid", "dashed"),
             color = c("red", "black", "red")) +
  scale_color_manual(values = penguin_colors) +
  labs(title = "Model Residuals Diagnostic",
       subtitle = "Species clustering suggests missing predictors",
       x = "Predicted Body Mass (g)", y = "Standardized Residuals", color = "Species") +
  theme_minimal()

ggsave("analysis/figures/model-diagnostics.png", plot = diagnostic_plot, width = 8, height = 5, dpi = 300)
cat("  ✅ Saved: analysis/figures/model-diagnostics.png\n")

cat("\n✅ All figures generated successfully!\n")
