# Minimal roxygen-to-Rd converter (base R only).
#
# roxygen2 could not be loaded on the development machine (its compiled
# dependencies are blocked by the operating system's application control
# policy), so this script turns the roxygen comments in timeledger/R/ into
# man/*.Rd and NAMESPACE. It supports only the tags used in this package:
# title/description/details paragraphs, @param, @return, @examples, @export,
# @rdname, @inheritParams, @seealso, markdown `code`, **bold**, [fun()]
# links and "* " bullet lists. On a machine where roxygen2 works,
# roxygen2::roxygenise("timeledger") regenerates the same documentation.
#
# Usage: Rscript tools/make_rd.R timeledger

args <- commandArgs(TRUE)
pkg <- if (length(args)) args[1] else "timeledger"
files <- list.files(file.path(pkg, "R"), "\\.R$", full.names = TRUE)
env <- new.env()
for (f in files) sys.source(f, envir = env)

md <- function(x) {
  x <- gsub("\\\\eqn\\{", "\001EQN{", x)
  x <- gsub("%", "\\\\%", x)
  # [fun()] links
  x <- gsub("\\[([A-Za-z0-9_.]+)\\(\\)\\]", "\\\\code{\\\\link[=\\1]{\\1()}}", x)
  x <- gsub("\\[graphics::plot\\(\\)\\]", "\\\\code{\\\\link[graphics:plot.default]{graphics::plot()}}", x)
  x <- gsub("\\*\\*([^*]+)\\*\\*", "\\\\strong{\\1}", x)
  x <- gsub("`([^`]+)`", "\\\\code{\\1}", x)
  x <- gsub("\001EQN\\{", "\\\\eqn{", x)
  x
}

# Convert a block of text lines with "* " bullets into Rd.
para <- function(lines) {
  out <- character()
  inlist <- FALSE
  for (l in lines) {
    if (grepl("^\\s*\\* ", l)) {
      if (!inlist) {
        out <- c(out, "\\itemize{")
        inlist <- TRUE
      }
      out <- c(out, paste0("\\item ", md(sub("^\\s*\\* ", "", l))))
    } else if (inlist && grepl("^\\s+\\S", l)) {
      out[length(out)] <- paste(out[length(out)], md(trimws(l)))
    } else {
      if (inlist) {
        out <- c(out, "}")
        inlist <- FALSE
      }
      out <- c(out, md(l))
    }
  }
  if (inlist) out <- c(out, "}")
  paste(out, collapse = "\n")
}

blocks <- list()
for (f in files) {
  x <- readLines(f, warn = FALSE)
  i <- 1
  while (i <= length(x)) {
    if (grepl("^#'", x[i])) {
      j <- i
      while (j <= length(x) && grepl("^#'", x[j])) j <- j + 1
      body <- sub("^#' ?", "", x[i:(j - 1)])
      # object name from the next code line
      k <- j
      while (k <= length(x) && !nzchar(trimws(x[k]))) k <- k + 1
      code <- x[k]
      nm <- sub("^`?([^` ]+)`?\\s*<-.*$", "\\1", code)
      blocks[[length(blocks) + 1]] <- list(body = body, name = nm, file = f)
      i <- j
    } else {
      i <- i + 1
    }
  }
}

parse_block <- function(b) {
  body <- b$body
  tagline <- grepl("^@", body)
  first_tag <- if (any(tagline)) which(tagline)[1] else length(body) + 1
  text <- body[seq_len(first_tag - 1)]
  # paragraphs
  paras <- split(text, cumsum(!nzchar(text)))
  paras <- lapply(paras, function(p) p[nzchar(p)])
  paras <- paras[lengths(paras) > 0]
  tags <- list()
  if (first_tag <= length(body)) {
    cur <- NULL
    for (l in body[first_tag:length(body)]) {
      if (grepl("^@", l)) {
        tg <- sub("^@(\\w+).*$", "\\1", l)
        rest <- sub("^@\\w+\\s?", "", l)
        cur <- length(tags) + 1
        tags[[cur]] <- list(tag = tg, text = rest)
      } else {
        tags[[cur]]$text <- c(tags[[cur]]$text, l)
      }
    }
  }
  list(name = b$name, title = if (length(paras)) paste(paras[[1]], collapse = " ") else NULL,
       desc = if (length(paras) > 1) paras[[2]] else NULL,
       details = if (length(paras) > 2) paras[-(1:2)] else NULL, tags = tags)
}

pb <- lapply(blocks, parse_block)
gettag <- function(p, t) Filter(function(z) z$tag == t, p$tags)

usage_of <- function(nm) {
  f <- get(nm, envir = env)
  fm <- formals(f)
  a <- vapply(names(fm), function(n) {
    if (is.symbol(fm[[n]]) && !nzchar(as.character(fm[[n]]))) n
    else paste0(n, " = ", paste(deparse(fm[[n]], width.cutoff = 500L), collapse = ""))
  }, "")
  meth <- regmatches(nm, regexec("^(print|summary|plot|as\\.data\\.frame)\\.(tl_\\w+)$", nm))[[1]]
  head <- if (length(meth)) sprintf("\\method{%s}{%s}", meth[2], meth[3]) else nm
  # Wrap only between arguments, never inside a default value.
  lines <- character()
  cur <- paste0(head, "(")
  for (k in seq_along(a)) {
    piece <- paste0(a[k], if (k < length(a)) "," else ")")
    if (nchar(cur) + nchar(piece) + 1 > 78 && !grepl("\\($", cur)) {
      lines <- c(lines, cur)
      cur <- paste0("  ", piece)
    } else {
      cur <- if (grepl("\\($", cur)) paste0(cur, piece) else paste(cur, piece)
    }
  }
  if (!length(a)) cur <- paste0(cur, ")")
  c(lines, cur)
}

# Group by rdname
topic <- vapply(pb, function(p) {
  r <- gettag(p, "rdname")
  if (length(r)) trimws(r[[1]]$text[1]) else p$name
}, "")
exports <- character()
s3 <- character()
for (p in pb) {
  if (length(gettag(p, "export"))) {
    m <- regmatches(p$name, regexec("^(print|summary|plot|as\\.data\\.frame)\\.(tl_\\w+)$", p$name))[[1]]
    if (p$name == "[.tl_ledger") {
      s3 <- c(s3, 'S3method("[", tl_ledger)')
    } else if (length(m)) {
      s3 <- c(s3, sprintf("S3method(%s, %s)", m[2], m[3]))
    } else {
      exports <- c(exports, sprintf("export(%s)", p$name))
    }
  }
}
writeLines(c("# Generated by tools/make_rd.R: do not edit by hand", sort(unique(exports)),
             sort(unique(s3))), file.path(pkg, "NAMESPACE"))

params_of <- function(p) {
  ps <- gettag(p, "param")
  out <- list()
  for (q in ps) {
    nm <- sub("^(\\S+).*$", "\\1", q$text[1])
    txt <- c(sub("^\\S+\\s*", "", q$text[1]), q$text[-1])
    out[[nm]] <- para(txt)
  }
  out
}

dir.create(file.path(pkg, "man"), showWarnings = FALSE)
unlink(list.files(file.path(pkg, "man"), "\\.Rd$", full.names = TRUE))
for (tp in unique(topic)) {
  members <- pb[topic == tp]
  has_title <- vapply(members, function(p) !is.null(p$title), TRUE)
  if (!any(has_title)) next  # registered S3 method without its own page
  main <- members[[which(has_title)[1]]]
  docd <- Filter(function(p) !is.null(p$title) || length(gettag(p, "rdname")), members)
  names_all <- vapply(docd, `[[`, "", "name")
  pars <- list()
  for (p in docd) {
    inh <- gettag(p, "inheritParams")
    pp <- params_of(p)
    pars[names(pp)] <- pp
    if (length(inh)) {
      src <- pb[[which(vapply(pb, `[[`, "", "name") == trimws(inh[[1]]$text[1]))]]
      sp <- params_of(src)
      f <- formals(get(p$name, envir = env))
      for (n in names(f)) if (is.null(pars[[n]]) && !is.null(sp[[n]])) pars[[n]] <- sp[[n]]
    }
  }
  # Keep params that are formals of a documented function, in formal order.
  fnames <- unique(unlist(lapply(names_all, function(n) names(formals(get(n, envir = env))))))
  # Group comma-separated params like "start,end"
  keys <- names(pars)
  covered <- unique(unlist(strsplit(keys, ",")))
  ordered <- keys[order(match(sub(",.*$", "", keys), fnames))]
  missing_par <- setdiff(fnames, covered)
  if (length(missing_par)) message(sprintf("[%s] undocumented arguments: %s", tp, paste(missing_par, collapse = ", ")))
  rd <- c("% Generated by tools/make_rd.R from roxygen comments: do not edit by hand",
          sprintf("\\name{%s}", tp))
  for (n in names_all) {
    al <- if (n == "[.tl_ledger") "sub-.tl_ledger" else n
    if (n != tp) rd <- c(rd, sprintf("\\alias{%s}", n))
    else rd <- c(rd, sprintf("\\alias{%s}", al))
  }
  if (!(tp %in% names_all)) rd <- c(rd, sprintf("\\alias{%s}", tp))
  rd <- c(rd, sprintf("\\title{%s}", md(main$title)))
  if (!is.null(main$desc)) rd <- c(rd, "\\description{", para(main$desc), "}")
  else rd <- c(rd, "\\description{", md(main$title), "}")
  rd <- c(rd, "\\usage{", unlist(lapply(names_all, usage_of)), "}")
  if (length(ordered)) {
    rd <- c(rd, "\\arguments{")
    for (k in ordered) rd <- c(rd, sprintf("\\item{%s}{%s}", k, pars[[k]]))
    rd <- c(rd, "}")
  }
  det <- unlist(lapply(docd, function(p) p$details), recursive = FALSE)
  if (length(det)) {
    rd <- c(rd, "\\details{", paste(vapply(det, para, ""), collapse = "\n\n"), "}")
  }
  rv <- unlist(lapply(docd, function(p) lapply(gettag(p, "return"), function(z) z$text)))
  if (length(rv)) rd <- c(rd, "\\value{", para(rv), "}")
  sa <- unlist(lapply(docd, function(p) lapply(gettag(p, "seealso"), function(z) z$text)))
  if (length(sa)) rd <- c(rd, "\\seealso{", para(sa), "}")
  ex <- unlist(lapply(docd, function(p) lapply(gettag(p, "examples"), function(z) z$text[-1])))
  ex <- c(unlist(lapply(docd, function(p) lapply(gettag(p, "examples"), function(z) {
    t <- z$text
    if (nzchar(t[1])) t else t[-1]
  }))))
  if (length(ex)) rd <- c(rd, "\\examples{", gsub("%", "\\\\%", ex), "}")
  fn <- gsub("[^A-Za-z0-9_.-]", "-", tp)
  writeLines(rd, file.path(pkg, "man", paste0(fn, ".Rd")))
}
cat("Wrote", length(unique(topic)), "Rd files and NAMESPACE\n")
