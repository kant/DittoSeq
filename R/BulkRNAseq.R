#' The RNAseq Class
#' @importFrom methods new slotNames
#' @importFrom stats median prcomp sd
#'
#' @description The RNAseq object stores data analyzed in DESeq2 in a structure similar to a Seurat-object.  This is the data structure required for DittoSeq plottign functions to access bulk RNAseq data.  All that is needed to create an RNAseq object is a DESeqDataSet output from the DESeq() function.
#' @slot counts a matrix. The raw genes x samples counts data. It is recommended, but not required, that one of these should be given when a new RNBAseq object is created.
#' @slot dds a DESeqDataSet. The output of having run DESeq() on your data.
#' @slot data a matrix. The regularized log correction of the counts data generated by a call to DESeq's rlog function.
#' @slot meta.data a data.frame that contains meta-information about each sample. Autopopulated from the DESeq upon import, or added to manually afterward. Can be sample names, conditions, timepoints, Nreads (the number of reads).
#' @slot reductions a list of dimensional reductions that have been run. Any type of reduction can technically be supported, but the only one included with my package is pca by prcomp. Embeddings are stored in the reductions$pca$x slot.
#' @slot var.genes vector of genes with high coefficient of variation that passed an expression filter, and would therefore be included the default principal components analysis calculation.
#' @slot samples a vector of names of the samples.
#' @slot exp.filter a logical vector showing whether each gene passed the expression filter (default: at least 1 count in 75 percent of samples from each condition)
#' @slot CVs a numeric vector showing the coefficient of variation (mean divided by sd) for each gene in the dataset.
#' @slot other A great place to store any other data associated with your bulk experiment that does not fit elsewhere in the object.  Components of the list can be of any type.  Left empty by default, and is not altered or used by any of the DittoSeq functions.
#' @export

Class <- setClass("RNAseq",
                  representation(
                    counts = "matrix",
                    dds = "ANY",
                    data = "matrix",
                    meta.data = "data.frame",
                    reductions = "list",
                    var.genes = "character",
                    samples = "character",
                    exp.filter = "logical",
                    CVs = "numeric",
                    other = "list"
                  ))

#### import.DESeq2 builds an RNAseq object with a DESeq input.  Can run PCA as well. ####
#' Creates an RNAseq object from a DESeq object.
#'
#' @description The first step of visualization of DESeq-analyzed bulk RNAseq data is running this function. Doing will extract meta.data information from the DESeq object, data using the rlog function, and if run_PCA=TRUE, will populate all other slots as well.
#' @param dds                The output of running DESeq() on your data. = The DESeq2 object for your data. REQUIRED.
#' @param counts             Matrix. The raw counts data matrix.  Not required but HIGHLY RECOMMENDED.
#' @param run_PCA            TRUE/FALSE. Default is False. If set to true, prcomp PCA calculation will be carried out with the PCAcalc function.  var.genes, reductions$pca, exp.filter, and CVs slots will then all be populated. For more info, run ?PCAcalc
#' @param pc.genes           NULL or vector of genes. Alternately to the method of genes selection used by PCAcalc by default, a set of genes can be given here.  Default = NULL. If left that way, a per condition expression filter will be applied, followed by a selection of Ngenes number of genes that have the highest coefficient of variation (CV=mean over sd).
#' @param Ngenes             #. How many genes to use for the PCA calculation. (This number will ultimately be the length of the var.genes slot)
#' @param blind              TRUE/FALSE. Whether rlog estimation should be blinded to sample info. Run `?rlog` for more info about whether it should.  Defaults to TRUE, but that is NOT the correct way for all experiments.
#' @param percent.samples    # between 0 and 1. The percent of samples within each condition that must express the gene in order for a gene to be included in the PCA calculation.
#' @return Outputs an RNAseq object.
#' @examples
#'
#' #Generate mock RNAseq counts and a DESeq object from the mock data
#' # count tables from RNA-Seq data
#' counts.table <- matrix(rnbinom(n=1000, mu=100, size=1/0.5), ncol=10)
#' colnames(counts.table) <- paste0("Sample",1:10)
#' conditions <- factor(rep(1:2, each=5))
#' # object construction
#' library(DESeq2)
#' dds <- DESeqDataSetFromMatrix(counts.table, DataFrame(conditions), ~ conditions)
#' dds <- DESeq(dds)
#'
#' # Recommended usage
#' # obj <- import.DESeq2(dds, counts = counts.table, run_PCA = TRUE)
#' #NOTE: the PCA calculation fails on this fake data because of it was normally randomized.
#' # Minimal input:
#' obj <- import.DESeq2(dds)
#'
#' @export

import.DESeq2 <- function(dds, #A DESeq object, *the output of DESeq()*
                          run_PCA = FALSE,#If changed to TRUE, function will:
                          # auto-populate var.genes, CVs, and pca fields.
                          pc.genes = NULL,
                          Ngenes = 2500, #How many genes to use for running PCA, (and how many genes
                          # will be stored in @var.genes)
                          blind = FALSE, #Whether or not the rlog estimation should be blinded to sample info.
                          # Run `?rlog` for more info
                          counts = NULL, #Raw Counts data, matrix with columns = genes and rows = samples.
                          # not required, but can be provided.
                          percent.samples = 75
){

  ########## Create the Object ########################
  #Create the object with whatever inputs were given, a.k.a. creates objects@counts and any other level
  # within str(object).  Will all be NULL unless provided in the function call
  object <- new("RNAseq", dds = dds)

  ########## Run Autopopulations ######################
  # Will run by default because this function requires a dds object to be given.
  ##populate dds
  object@dds <- dds
  ##populate @counts
  #Use the data provided if it was, otherwise, grab from the dds
  if (!(is.null(counts))) {object@counts <- counts
  } else {object@counts <- counts(dds)}
  ##populate @samples
  object@samples <- colnames(object@counts)
  ##populate some of @meta.data
  #   1st add samples, then Nreads.
  object@meta.data <- data.frame(Samples = object@samples,
                                 Nreads = colSums(object@counts))
  rownames(object@meta.data) <- object@samples

  ##Also add colData from dds to @meta.data slot
  #Turn colData into a data.frame, and merge that with current meta.data, BUT do not include any
  # dublicate sets.  For example, Samples will be ignored in colData because it was already grabbed
  # from the counts matrix
  object@meta.data <- cbind(object@meta.data,
                            data.frame(object@dds@colData@listData)[(!duplicated(
                              c(names(data.frame(object@dds@colData@listData)),names(object@meta.data)),
                              fromLast=TRUE
                            ))[seq_along(object@dds@colData@listData)]])

  ##populate data
  object@data <- SummarizedExperiment::assay(DESeq2::rlog(object@dds, blind = blind))

  ########## Will run if run_PCA = TRUE ##################
  ##Will populate: pca, CVs, and var.genes
  if (run_PCA){
    object <- PCAcalc(object = object,
                      genes.use = pc.genes,
                      Ngenes = Ngenes,
                      percent.samples = percent.samples,
                      name = "pca")
  }
  #OUTPUT: (This is how functions "work" in R.  The final line is what they return.)
  object
}

###### PCAcalc: For running the PCA calculation on an RNAseq object ############
#' Wrapper for running prcomp on an RNAseq object
#'
#' @description This function will run prcomp PCA calculation on either a set of genes given by the genes.use slot, or on the Ngenes that have the highest coefficient of variation (CV=mean/sd) after a per experimental condition (extracted from the dds) expression filter is applied.
#' @param object             the RNAseq object = REQUIRED, unless `DEFAULT <- "object"` has been run.
#' @param genes.use          NULL or a vector of genes.  This will set the genes to be used by the prcomp PCA calculation.  NOTE: this list will not be used to populate the var.genes slot, but you can do that manually if you want to.
#' @param Ngenes             #. How many genes to use for the PCA calculation. (This number will ultimately be the length of the var.genes slot)
#' @param percent.samples    # between 0 and 100. The percent of samples within each condition that must express the gene in order for a gene to be included in the PCA calculation.
#' @param name               "name". Example: "pca". The name to be given to this pca reduction slot. -> redution$'name'
#' @return Outputs an RNAseq object with a new reductions$'name' slot.
#' @examples
#' # If bulkObject is the name of an RNAseq object in your workspace...
#' # PCAcalc("bulkObject", Ngenes = 2500, percent.samples = 75, name = "pca")
#' # Minimal input that does the same thing:
#' # PCAcalc("bulkObject")
#'
#' @export

PCAcalc <- function(object = DEFAULT,
                    genes.use = NULL,
                    Ngenes = 2500, #How many genes to use for running PCA, (and how many genes
                    # will be stored in @var.genes)
                    percent.samples = 75,
                    name = "pca"
){

  #Turn the percent.samples into a decimal named cutoff
  cutoff <- percent.samples/100

  #grab the object if given an object name
  if(typeof(object)=="character"){object <- eval(expr = parse(text = paste0(object)))}

  ######### IF no genes.use given, use the CVs and ExpFilter to pick genes ###########
  if(is.null(genes.use)){
    #Filter data to only the genes expressed in at least 75% of samples from test group (ONLY WORKS FOR ONE TEST GROUP)
    test_meta <- strsplit(as.character(object@dds@design), split = "~")[[2]][1]
    #Store this metadata as an easily accessible variable to speed up the next step.
    classes <- meta(test_meta, object)
    #For each gene, return TRUE if... the gene is expressed in >cutoff% of samples from each condition used to build the dds
    ##populate exp.filter
    object@exp.filter <- sapply(1:dim(object@counts)[1], function(X)
      #Ensures that the #of classifications = the number TRUEs in what the nested sapply produces
      length(levels(as.factor(classes)))==sum(
        #For each classification of the test variable, check for >= cutoff% expression accross samples
        #This half sets a variable to each of the saparate classifications,
        # and says to run the next lines on each
        sapply(levels(as.factor(classes)), function(Y)
          #This part of the function determine how many of the samples express the gene
          (sum(object@counts[X, classes==Y]>0))
          #This part compares the above to (the number of samples of the current classification*cutoff%)
          >= (sum(classes==Y)*cutoff)
        )
      )
    )
    data_for_prcomp <- as.data.frame(object@data)[object@exp.filter,]
    #calculate CV by dividing mean by sd
    ## populate CVs
    object@CVs <- apply(X = object@data, MARGIN = 1, FUN = sd)/apply(X = object@data, MARGIN = 1, FUN = mean)
    #Trim rlog data and RawCV_rlog by expression filter variable = object@exp.filter
    #arrange by CV_rank, higher CVs first
    data_for_prcomp<- data_for_prcomp[order(object@CVs[object@exp.filter], decreasing = TRUE),]
    ##populate var.genes
    object@var.genes <- rownames(data_for_prcomp)[1:(min(Ngenes,dim(data_for_prcomp)[1]))]
    ##populate pca : Run PCA on the top Ngenes CV genes that survive the cutoff% expression per condition filter
    object@reductions$a1b2c3d57 <- prcomp(t(data_for_prcomp[1:Ngenes,]), center = TRUE, scale = TRUE)
  }
  ######### IF genes.use given, use them  ###########
  if(!(is.null(genes.use))){
    #Filter rlog to only the genes in genes.use
    data_for_prcomp <- as.data.frame(object@data)[genes.use,]
    ##populate pca : Run PCA on the top given genes.  DOES NOT USE THE Ngenes or percent.samples inputs!
    object@reductions$a1b2c3d57 <- list(prcomp(t(data_for_prcomp), center = TRUE, scale = TRUE))
  }

  names(object@reductions)[grep("a1b2c3d57",names(object@reductions))] <- name
  object
}
