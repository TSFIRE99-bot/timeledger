# Evaluate the article's setup chunks and inline R expressions and write a
# plain Markdown draft (no figures) for proofreading. This stands in for
# knitting where knitr cannot be loaded; it is not the submission format.
# Usage: Rscript tools/render_inline.R paper/timeledger.Rmd paper/timeledger_draft.md
args <- commandArgs(TRUE)
x <- readLines(args[1], warn = FALSE, encoding = "UTF-8")
env <- new.env()
# YAML header: keep title and abstract.
yend <- which(x == "---")[2]
yaml <- x[1:yend]
title <- sub('^title: "(.*)"$', "\\1", grep("^title:", yaml, value = TRUE))
ab_start <- grep("^abstract:", yaml) + 1
ab_end <- grep("^draft:", yaml) - 1
abstract <- paste(trimws(yaml[ab_start:ab_end]), collapse = " ")
body <- x[(yend + 1):length(x)]
# Chunks: evaluate setup/numbers/demo chunks; replace figure chunks by caption.
out <- character()
i <- 1
figs <- character()
tabs <- character()
while (i <= length(body)) {
  l <- body[i]
  if (grepl("^```[{]r", l)) {
    j <- i + 1
    while (!grepl("^```[[:space:]]*$", body[j])) j <- j + 1
    code <- body[(i + 1):(j - 1)]
    label <- sub("^```[{]r ([A-Za-z0-9_-]+).*$", "\\1", l)
    if (grepl("knitr::", paste(code, collapse = "")) && label == "setup") {
      # skip knitr options
    } else if (grepl("fig.cap", l)) {
      figs <- c(figs, label)
      cap <- sub('.*fig.cap = "([^"]*)".*', "\\1", l)
      out <- c(out, sprintf("[Figure %d: %s]", length(figs), cap), "")
    } else if (grepl("echo = TRUE", l)) {
      out <- c(out, "```r", code, "```", "")
      for (e in parse(text = code)) eval(e, env)
    } else if (any(grepl("knitr::kable", code))) {
      kl <- grep("knitr::kable", code)[1]
      for (e in parse(text = code[seq_len(kl - 1)])) eval(e, env)
      obj <- sub("^.*knitr::kable[(]([A-Za-z0-9_.]+).*$", "\\1", code[kl])
      p <- get(obj, env)
      tabs <- c(tabs, label)
      out <- c(out, sprintf("[Table %d]", length(tabs)),
               apply(p, 1, paste, collapse = " | "), "")
    } else {
      grDevices::pdf(NULL)
      for (e in parse(text = code)) eval(e, env)
      grDevices::dev.off()
    }
    i <- j + 1
    next
  }
  out <- c(out, l)
  i <- i + 1
}
txt <- paste(out, collapse = "\n")
# Inline R.
repeat {
  m <- regexpr("`r [^`]+`", txt)
  if (m < 0) break
  expr <- substr(txt, m + 3, m + attr(m, "match.length") - 2)
  val <- paste(format(eval(parse(text = expr), env)), collapse = ", ")
  txt <- paste0(substr(txt, 1, m - 1), val, substr(txt, m + attr(m, "match.length"), nchar(txt)))
}
for (k in seq_along(figs)) {
  txt <- gsub(sprintf("Figure \\\\@ref\\(fig:%s\\)", figs[k]), paste("Figure", k), txt)
  txt <- gsub(sprintf("\\\\@ref\\(fig:%s\\)", figs[k]), k, txt)
}
for (k in seq_along(tabs)) {
  txt <- gsub(sprintf("Table \\\\@ref\\(tab:%s\\)", tabs[k]), paste("Table", k), txt)
}
txt <- gsub("\\\\(CRANpkg|BIOpkg|pkg)\\{([^}]+)\\}", "\\2", txt)
writeLines(c(paste("#", title), "", "Abstract.", abstract, "", txt), args[2], useBytes = TRUE)
cat("wrote", args[2], "\n")
