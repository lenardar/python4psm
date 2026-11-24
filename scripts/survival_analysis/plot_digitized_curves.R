library(ggplot2)

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
stopifnot(length(script_arg) == 1L)
script_dir <- dirname(normalizePath(sub("^--file=", "", script_arg)))
root <- dirname(dirname(script_dir))
analysis_dir <- file.path(root, "output", "survival_analysis")
dir.create(file.path(analysis_dir, "images"), recursive = TRUE, showWarnings = FALSE)
colors <- c("Dato-DXd" = "#A40063", "ICC" = "#005493")

for (endpoint in c("pfs", "os")) {
  curves <- lapply(c("dato", "icc"), function(arm) {
    points <- read.csv(
      file.path(root, "data", "survival", paste0(endpoint, "_", arm, ".csv")),
      header = FALSE,
      col.names = c("time", "survival")
    )
    stopifnot(
      nrow(points) > 1L,
      is.numeric(points$time),
      is.numeric(points$survival),
      all(is.finite(points$time)),
      all(is.finite(points$survival))
    )
    points <- points[order(points$time), ]
    points$arm <- if (arm == "dato") "Dato-DXd" else "ICC"
    message(sprintf(
      "%s %s: %d points; %d negative times; %d probabilities outside [0, 1]",
      toupper(endpoint), arm, nrow(points),
      sum(points$time < 0), sum(points$survival < 0 | points$survival > 1)
    ))
    points
  })
  curves <- do.call(rbind, curves)
  curves$arm <- factor(curves$arm, levels = names(colors))
  max_time <- if (endpoint == "pfs") 16 else 36

  plot <- ggplot(curves, aes(time, survival, color = arm)) +
    geom_line(linewidth = 0.9) +
    scale_color_manual(values = colors) +
    scale_x_continuous(breaks = seq(0, max_time, 3)) +
    scale_y_continuous(breaks = seq(0, 1, 0.2)) +
    coord_cartesian(xlim = c(0, max_time), ylim = c(0, 1), expand = FALSE) +
    labs(
      title = toupper(endpoint),
      x = "Time since randomization (months)",
      y = if (endpoint == "pfs") {
        "Progression-free survival probability"
      } else {
        "Overall survival probability"
      },
      color = NULL
    ) +
    theme_classic(base_size = 14) +
    theme(
      plot.title = element_text(face = "bold", size = 18),
      legend.position = "top",
      legend.justification = "left",
      axis.text = element_text(color = "black"),
      plot.margin = margin(12, 18, 12, 12)
    )

  for (extension in c("png", "pdf")) {
    ggsave(
      filename = file.path(
        analysis_dir, "images", paste0(endpoint, "_redrawn.", extension)
      ),
      plot = plot,
      width = 7.2,
      height = 5.2,
      dpi = 300,
      bg = "white"
    )
  }
}
