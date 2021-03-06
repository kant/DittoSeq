% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/Demuxlet_Tools.R
\name{demux.calls.summary}
\alias{demux.calls.summary}
\title{Plots the number of annotations per sample, per lane}
\usage{
demux.calls.summary(object = DEFAULT, singlets.only = TRUE,
  main = "Sample Annotations by Lane", sub = NULL,
  ylab = "Annotations", xlab = "Sample", color = MYcolors[2],
  theme = NULL, rotate.labels = TRUE)
}
\arguments{
\item{object}{the Seurat Object = name of object in "quotes". REQUIRED, unless `DEFAULT <- "object"` has been run.}

\item{singlets.only}{Whether to only show data for cells called as singlets by demuxlet. Default is TRUE. Note: if doublets are included, only one of their sample calls will be used.}

\item{main}{plot title. Default = "Sample Annotations by Lane"}

\item{sub}{plot subtitle}

\item{ylab}{y axis label, default is "Annotations"}

\item{xlab}{x axis label, default is "Sample"}

\item{color}{bars color. Default is blue.}

\item{theme}{A complete ggplot theme. Default is a modified theme_bw().}

\item{rotate.labels}{whether sample names / x-axis labels should be rotated or not. Default is TRUE.}
}
\value{
For a given Seurat object, summarizes how many cells in each lane were anotated to each sample.  Assumes that the Sample calls of each cells, and which lane each cell belonged to, are stored in 'Sample' and 'Lane' metadata slots, respectively, as would be the case if the Seurat object was created with the Import10XDemux function.
}
\description{
Plots the number of annotations per sample, per lane
}
\examples{
#Data required for an example would be rather large.  For an example, see the online vignette.
}
