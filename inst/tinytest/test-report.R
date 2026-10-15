# Static checks on the Quarto report: front matter and every file it
# reads. Rendering itself needs Quarto and LaTeX and is left to
# `make docker-render`.

report_dir <- here::here('analysis', 'report')
report_path <- file.path(report_dir, 'index.qmd')

expect_true(file.exists(report_path), info = 'index.qmd exists')

for (pkg in c('rmarkdown', 'knitr')) {
  expect_true(
    requireNamespace(pkg, quietly = TRUE),
    info = paste('report dependency installed:', pkg)
  )
}

front_matter <- rmarkdown::yaml_front_matter(report_path)
expect_true(is.list(front_matter), info = 'front matter parses')
for (field in c('title', 'author', 'date', 'description')) {
  expect_true(
    field %in% names(front_matter),
    info = paste('front matter has', field)
  )
}

# Paths in the report are relative to analysis/report; figures/ and
# media/ are symlinks into analysis/.
report_lines <- readLines(report_path, warn = FALSE)
referenced <- regmatches(
  report_lines,
  regexpr('(data|figures|media)/[A-Za-z0-9_./-]+\\.(csv|rds|png)',
    report_lines)
)
referenced <- unique(referenced)

expect_true(length(referenced) > 0, info = 'report references files')
for (f in referenced) {
  expect_true(
    file.exists(file.path(report_dir, f)),
    info = paste('report input exists:', f)
  )
}
