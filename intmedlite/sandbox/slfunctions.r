mySL <- function (Y, X, newX = NULL, family = gaussian(), SL.library,
    method = "method.NNLS", id = NULL, verbose = FALSE, control = list(),
    cvControl = list(), obsWeights = NULL, env = parent.frame(), validRows)
{
    time_start = proc.time()
    if (is.character(method)) {
        if (exists(method, mode = "list")) {
            method <- get(method, mode = "list")
        }
        else if (exists(method, mode = "function")) {
            method <- get(method, mode = "function")()
        }
    }
    else if (is.function(method)) {
        method <- method()
    }
    if (!is.list(method)) {
        stop("method is not in the appropriate format. Check out help('method.template')")
    }
    if (!is.null(method$require)) {
        sapply(method$require, function(x) require(force(x),
            character.only = TRUE))
    }
    control <- do.call("SuperLearner.control", control)
    cvControl <- do.call("SuperLearner.CV.control", cvControl)
    library <- .createLibrary(SL.library)
    .check.SL.library(library = c(unique(library$library$predAlgorithm),
        library$screenAlgorithm))
    call <- match.call(expand.dots = TRUE)
    if (!inherits(X, "data.frame"))
        message("X is not a data frame. Check the algorithms in SL.library to make sure they are compatible with non data.frame inputs")
    varNames <- colnames(X)
    N <- dim(X)[1L]
    p <- dim(X)[2L]
    k <- nrow(library$library)
    kScreen <- length(library$screenAlgorithm)
    Z <- matrix(NA, N, k)
    libraryNames <- paste(library$library$predAlgorithm, library$screenAlgorithm[library$library$rowScreen],
        sep = "_")
    fitLibEnv <- new.env()
    assign("fitLibrary", vector("list", length = k), envir = fitLibEnv)
    assign("libraryNames", libraryNames, envir = fitLibEnv)
    evalq(names(fitLibrary) <- libraryNames, envir = fitLibEnv)
    errorsInCVLibrary <- rep(0, k)
    errorsInLibrary <- rep(0, k)
    if (is.null(newX)) {
        newX <- X
    }
    if (!identical(colnames(X), colnames(newX))) {
        stop("The variable names and order in newX must be identical to the variable names and order in X")
    }
    if (sum(is.na(X)) > 0 | sum(is.na(newX)) > 0 | sum(is.na(Y)) >
        0) {
        stop("missing data is currently not supported. Check Y, X, and newX for missing values")
    }
    if (!is.numeric(Y)) {
        stop("the outcome Y must be a numeric vector")
    }
    if (is.character(family))
        family <- get(family, mode = "function", envir = parent.frame())
    if (is.function(family))
        family <- family()
    if (is.null(family$family)) {
        print(family)
        stop("'family' not recognized")
    }
    if (family$family != "binomial" & isTRUE("cvAUC" %in% method$require)) {
        stop("'method.AUC' is designed for the 'binomial' family only")
    }
    ## validRows <- CVFolds(N = N, id = id, Y = Y, cvControl = cvControl)
    if (is.null(id)) {
        id <- seq(N)
    }
    if (!identical(length(id), N)) {
        stop("id vector must have the same dimension as Y")
    }
    if (is.null(obsWeights)) {
        obsWeights <- rep(1, N)
    }
    if (!identical(length(obsWeights), N)) {
        stop("obsWeights vector must have the same dimension as Y")
    }
    .crossValFUN <- function(valid, Y, dataX, id, obsWeights,
        library, kScreen, k, p, libraryNames) {
        tempLearn <- dataX[-valid, , drop = FALSE]
        tempOutcome <- Y[-valid]
        tempValid <- dataX[valid, , drop = FALSE]
        tempWhichScreen <- matrix(NA, nrow = kScreen, ncol = p)
        tempId <- id[-valid]
        tempObsWeights <- obsWeights[-valid]
        for (s in seq(kScreen)) {
            screen_fn = get(library$screenAlgorithm[s], envir = env)
            testScreen <- try(do.call(screen_fn, list(Y = tempOutcome,
                X = tempLearn, family = family, id = tempId,
                obsWeights = tempObsWeights)))
            if (inherits(testScreen, "try-error")) {
                warning(paste("replacing failed screening algorithm,",
                  library$screenAlgorithm[s], ", with All()",
                  "\n "))
                tempWhichScreen[s, ] <- TRUE
            }
            else {
                tempWhichScreen[s, ] <- testScreen
            }
            if (verbose) {
                message(paste("Number of covariates in ", library$screenAlgorithm[s],
                  " is: ", sum(tempWhichScreen[s, ]), sep = ""))
            }
        }
        out <- matrix(NA, nrow = nrow(tempValid), ncol = k)
        for (s in seq(k)) {
            pred_fn = get(library$library$predAlgorithm[s], envir = env)
            testAlg <- try(do.call(pred_fn, list(Y = tempOutcome,
                X = subset(tempLearn, select = tempWhichScreen[library$library$rowScreen[s],
                  ], drop = FALSE), newX = subset(tempValid,
                  select = tempWhichScreen[library$library$rowScreen[s],
                    ], drop = FALSE), family = family, id = tempId,
                obsWeights = tempObsWeights)))
            if (inherits(testAlg, "try-error")) {
                warning(paste("Error in algorithm", library$library$predAlgorithm[s],
                  "\n  The Algorithm will be removed from the Super Learner (i.e. given weight 0) \n"))
            }
            else {
                out[, s] <- testAlg$pred
            }
            if (verbose)
                message(paste("CV", libraryNames[s]))
        }
        invisible(out)
    }
    time_train_start = proc.time()
    Z[unlist(validRows, use.names = FALSE), ] <- do.call("rbind",
        lapply(validRows, FUN = .crossValFUN, Y = Y, dataX = X,
            id = id, obsWeights = obsWeights, library = library,
            kScreen = kScreen, k = k, p = p, libraryNames = libraryNames))
    errorsInCVLibrary <- apply(Z, 2, function(x) anyNA(x))
    if (sum(errorsInCVLibrary) > 0) {
        Z[, as.logical(errorsInCVLibrary)] <- 0
    }
    if (all(Z == 0)) {
        stop("All algorithms dropped from library")
    }
    getCoef <- method$computeCoef(Z = Z, Y = Y, libraryNames = libraryNames,
        obsWeights = obsWeights, control = control, verbose = verbose,
        errorsInLibrary = errorsInCVLibrary)
    coef <- getCoef$coef
    names(coef) <- libraryNames
    time_train = proc.time() - time_train_start
    if (!("optimizer" %in% names(getCoef))) {
        getCoef["optimizer"] <- NA
    }
    m <- dim(newX)[1L]
    predY <- matrix(NA, nrow = m, ncol = k)
    .screenFun <- function(fun, list) {
        screen_fn = get(fun, envir = env)
        testScreen <- try(do.call(screen_fn, list))
        if (inherits(testScreen, "try-error")) {
            warning(paste("replacing failed screening algorithm,",
                fun, ", with All() in full data", "\n "))
            out <- rep(TRUE, ncol(list$X))
        }
        else {
            out <- testScreen
        }
        return(out)
    }
    time_predict_start = proc.time()
    whichScreen <- t(sapply(library$screenAlgorithm, FUN = .screenFun,
        list = list(Y = Y, X = X, family = family, id = id, obsWeights = obsWeights)))
    .predFun <- function(index, lib, Y, dataX, newX, whichScreen,
        family, id, obsWeights, verbose, control, libraryNames) {
        pred_fn = get(lib$predAlgorithm[index], envir = env)
        testAlg <- try(do.call(pred_fn, list(Y = Y, X = subset(dataX,
            select = whichScreen[lib$rowScreen[index], ], drop = FALSE),
            newX = subset(newX, select = whichScreen[lib$rowScreen[index],
                ], drop = FALSE), family = family, id = id, obsWeights = obsWeights)))
        if (inherits(testAlg, "try-error")) {
            warning(paste("Error in algorithm", lib$predAlgorithm[index],
                " on full data", "\n  The Algorithm will be removed from the Super Learner (i.e. given weight 0) \n"))
            out <- rep.int(NA, times = nrow(newX))
        }
        else {
            out <- testAlg$pred
            if (control$saveFitLibrary) {
                eval(bquote(fitLibrary[[.(index)]] <- .(testAlg$fit)),
                  envir = fitLibEnv)
            }
        }
        if (verbose) {
            message(paste("full", libraryNames[index]))
        }
        invisible(out)
    }
    predY <- do.call("cbind", lapply(seq(k), FUN = .predFun,
        lib = library$library, Y = Y, dataX = X, newX = newX,
        whichScreen = whichScreen, family = family, id = id,
        obsWeights = obsWeights, verbose = verbose, control = control,
        libraryNames = libraryNames))
    errorsInLibrary <- apply(predY, 2, function(algorithm) anyNA(algorithm))
    if (sum(errorsInLibrary) > 0) {
        if (sum(coef[as.logical(errorsInLibrary)]) > 0) {
            warning(paste0("Re-running estimation of coefficients removing failed algorithm(s)\n",
                "Original coefficients are: \n", paste(coef,
                  collapse = ", "), "\n"))
            Z[, as.logical(errorsInLibrary)] <- 0
            if (all(Z == 0)) {
                stop("All algorithms dropped from library")
            }
            getCoef <- method$computeCoef(Z = Z, Y = Y, libraryNames = libraryNames,
                obsWeights = obsWeights, control = control, verbose = verbose,
                errorsInLibrary = errorsInLibrary)
            coef <- getCoef$coef
            names(coef) <- libraryNames
        }
        else {
            warning("Coefficients already 0 for all failed algorithm(s)")
        }
    }

    ## Below line has been modified from SuperLearner function to get
    ## cross-validated predictions. Using weights that are not cross-validated
    ## should be OK as the ensembling function IS Donkser.
    getPred <- method$computePred(predY = Z, coef = coef,
        control = control)

    ## getPred <- method$computePred(predY = predY, coef = coef,
    ##     control = control)
    time_predict = proc.time() - time_predict_start
    colnames(predY) <- libraryNames
    if (sum(errorsInCVLibrary) > 0) {
        getCoef$cvRisk[as.logical(errorsInCVLibrary)] <- NA
    }
    time_end = proc.time()
    times = list(everything = time_end - time_start, train = time_train,
        predict = time_predict)
    out <- list(call = call, libraryNames = libraryNames, SL.library = library,
        SL.predict = getPred, coef = coef, library.predict = predY,
        Z = Z, cvRisk = getCoef$cvRisk, family = family, fitLibrary = get("fitLibrary",
            envir = fitLibEnv), varNames = varNames, validRows = validRows,
        method = method, whichScreen = whichScreen, control = control,
        cvControl = cvControl, errorsInCVLibrary = errorsInCVLibrary,
        errorsInLibrary = errorsInLibrary, metaOptimizer = getCoef$optimizer,
        env = env, times = times)
    class(out) <- c("SuperLearner")
    return(out)
}

SL.myglmnet <- function (Y, X, newX, family, obsWeights, id, alpha = 1, nfolds = 10,
    nlambda = 500, useMin = TRUE, loss = "mse", ...)
{
    .SL.require("glmnet")
    if (!is.matrix(X)) {
        formula <- as.formula(paste('~ -1 + .^', eval(ncol(X))))
        X <- model.matrix(formula, X)
        newX <- model.matrix(formula, newX)
    }
    fitCV <- glmnet::cv.glmnet(x = X, y = Y, weights = obsWeights,
        lambda = NULL, type.measure = loss, nfolds = nfolds,
        family = "gaussian", lambda.min.ratio = 1 / nrow(X),
        alpha = alpha, nlambda = nlambda,
        ...)
    pred <- predict(fitCV, newx = newX, type = "response", s = ifelse(useMin,
        "lambda.min", "lambda.1se"))
    fit <- list(object = fitCV, useMin = useMin)
    class(fit) <- "SL.myglmnet"
    out <- list(pred = pred, fit = fit)
    return(out)
}

SL.myglm <- function (Y, X, newX, family, obsWeights, model = TRUE, ...)
{
    if (is.matrix(X)) {
        X = as.data.frame(X)
    }
    formula <- as.formula(paste('Y ~ .^', eval(ncol(X))))
    fit.glm <- glm(formula, data = X, family = family, weights = obsWeights,
        model = model)
    if (is.matrix(newX)) {
        newX = as.data.frame(newX)
    }
    pred <- predict(fit.glm, newdata = newX, type = "response")
    fit <- list(object = fit.glm)
    class(fit) <- "SL.glm"
    out <- list(pred = pred, fit = fit)
    return(out)
}

predict.SL.myglmnet <- function(object, newdata, remove_extra_cols = F, add_missing_cols = F,
    ...)
{
    .SL.require("glmnet")
    if (!is.matrix(newdata)) {
        formula <- as.formula(paste('~ -1 + .^', eval(ncol(newdata))))
        newdata <- model.matrix(formula, newdata)
    }
    original_cols = rownames(object$object$glmnet.fit$beta)
    if (remove_extra_cols) {
        extra_cols = setdiff(colnames(newdata), original_cols)
        if (length(extra_cols) > 0) {
            warning(paste("Removing extra columns in prediction data:",
                paste(extra_cols, collapse = ", ")))
            newdata = newdata[, !colnames(newdata) %in% extra_cols,
                drop = F]
        }
    }
    if (add_missing_cols) {
        missing_cols = setdiff(original_cols, colnames(newdata))
        if (length(missing_cols) > 0) {
            warning(paste("Adding missing columns in prediction data:",
                paste(missing_cols, collapse = ", ")))
            new_cols = matrix(0, nrow = nrow(newdata), ncol = length(missing_cols))
            colnames(new_cols) = missing_cols
            newdata = cbind(newdata, new_cols)
            newdata = newdata[, original_cols]
        }
    }
    pred <- predict(object$object, newx = newdata, type = "response",
        s = ifelse(object$useMin, "lambda.min", "lambda.1se"))
    return(pred)
}

SL.caretXGB <- function(Y, X, newX, family, obsWeights, ...) {
    SL.caret(Y, X, newX, family, obsWeights, method = 'xgbTree', tuneLength = 30,
             trControl =  caret::trainControl(method = "cv", number = 5, search = 'random',
                                              verboseIter = TRUE), ...)
}

SL.caretRF <- function(Y, X, newX, family, obsWeights, ...) {
    SL.caret(Y, X, newX, family, obsWeights, method = 'rf',  tuneLength = 20,
             trControl =  caret::trainControl(method = "cv", number = 5, search = 'random',
                                              verboseIter = TRUE), ...)
}

environment(mySL) <- environment(SuperLearner)
environment(SL.myglm) <- environment(SuperLearner)
environment(SL.myglmnet) <- environment(SuperLearner)
environment(predict.SL.myglmnet) <- environment(SuperLearner)
