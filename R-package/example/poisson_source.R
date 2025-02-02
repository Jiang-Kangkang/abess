metrics <- function(beta.fit, dat.test)
{
  coef.err <- norm(beta.fit - c(0, dat.test$beta), "2")
  y.pred <- exp(dat.test$x %*% beta.fit[-1] + beta.fit[1])
  pe <- norm(y.pred - dat.test$y, "2")
  nonzero.fit <- as.numeric(abs(beta.fit[-1]) > 1e-05)
  nonzero.true <- as.numeric(abs(dat.test$beta) > 1e-05)
  tpr <- length(which(nonzero.fit > 0 & nonzero.true > 0))/sum(nonzero.true)
  fpr <- length(which(nonzero.fit > 0 & nonzero.true == 0))/sum(!nonzero.true)
  mcc <- mccr(nonzero.true, nonzero.fit)
  return(c(coef.err = coef.err, pe = pe, tpr = tpr, fpr = fpr, mcc = mcc))
}


simu.glmnet <- function(dat, dat.test)
{
  ptm <- proc.time()
  res <- cv.glmnet(dat$x, dat$y, family = "poisson")
  t <- (proc.time() - ptm)[3]
  beta.fit <- coef(res, s = res$lambda.min)
  metrics.glmnet <- metrics(beta.fit, dat.test)
  return(c(metrics.glmnet, t = t))
}

simu.ncvreg <- function(dat, dat.test, penalty)
{
  ptm <- proc.time()
  res <- cv.ncvreg(dat$x, dat$y, penalty = penalty, family = "poisson")
  t <- (proc.time() - ptm)[3]
  beta.fit <- coef(res, lambda = res$lambda.min)
  metrics.ncvreg <- metrics(beta.fit, dat.test)
  return(c(metrics.ncvreg, t = t))
}

ncv.wrapper <- function(dat, dat.test, penalty)
{
  flag <- 1
  res.ncvreg <- NULL
  tryCatch({
    res.ncvreg <- simu.ncvreg(dat, dat.test, penalty)
  }, error = function(e)
  {
    flag <<- 0
  })
  return(list(flag = flag, res = res.ncvreg))
}

ncv.tryCatch <- function(dat, dat.test, penalty, i)
{
  res.ncvreg <- NULL
  tryCatch({
    res.ncvreg <- simu.ncvreg(dat, dat.test, penalty)
  }, error = function(e)
  {
    flag <- 0
    seed <- i
    while (!flag)
    {
      seed <- seed + 100
      dat <- generate.data(n, p, rho = rho, cortype = cortype, support.size = 10, 
                           family = "poisson", seed = seed)
      dat.test <- generate.data(n, p, rho = rho, cortype = cortype, 
                                beta = dat$beta, family = "poisson", seed = seed + 100)
      try.res <- ncv.wrapper(dat, dat.test, penalty)
      flag <- try.res$flag
      res.ncvreg <<- try.res$res
    }
    
  })
  return(res.ncvreg)
}

simu.abess <- function(dat, dat.test)
{
  ptm <- proc.time()
  res <- abess(dat$x, dat$y, support.size = 0:99, family = "poisson", 
               tune.type = "cv")
  t <- (proc.time() - ptm)[3]
  beta.fit <- coef(res, support.size = res$support.size[which.min(res$tune.value)])
  metrics.abess <- metrics(beta.fit, dat.test)
  return(c(metrics.abess, t = t))
}

simu <- function(i, n, p, rho, cortype, method = c("glmnet", "ncvreg.MCP", 
                                                   "ncvreg.SCAD", "ncvreg.lasso", "abess"))
{
  set.seed(i)
  dat <- generate.data(n, p, rho = rho, cortype = cortype, support.size = 10, 
                       family = "poisson", seed = i)
  dat.test <- generate.data(n, p, rho = rho, cortype = cortype, beta = dat$beta, 
                            family = "poisson", seed = i + 100)
  res.default <- rep(0, 6)
  if ("glmnet" %in% method)
  {
    res.glmnet <- simu.glmnet(dat, dat.test)
  } else
  {
    res.glmnet <- res.default
  }
  if ("ncvreg.MCP" %in% method)
  {
    res.ncvreg.MCP <- ncv.tryCatch(dat, dat.test, penalty = "MCP", 
                                   i)
  } else
  {
    res.ncvreg.MCP <- res.default
  }
  if ("ncvreg.SCAD" %in% method)
  {
    res.ncvreg.SCAD <- ncv.tryCatch(dat, dat.test, penalty = "SCAD", 
                                    i)
  } else
  {
    res.ncvreg.SCAD <- res.default
  }
  if ("ncvreg.lasso" %in% method)
  {
    res.ncvreg.lasso <- ncv.tryCatch(dat, dat.test, penalty = "lasso", 
                                     i)
  } else
  {
    res.ncvreg.lasso <- res.default
  }
  if ("abess" %in% method)
  {
    res.abess <- simu.abess(dat, dat.test)
  } else
  {
    res.abess <- res.default
  }
  return(rbind(res.glmnet, res.ncvreg.MCP, res.ncvreg.SCAD, res.ncvreg.lasso, 
               res.abess))
}