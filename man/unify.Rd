% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/unify.R
\name{unify}
\alias{unify}
\title{Unify tree-based model}
\usage{
unify(model, data, ...)
}
\arguments{
\item{model}{A tree-based model object of any supported class (\code{gbm}, \code{lgb.Booster}, \code{randomForest}, \code{ranger}, or \code{xgb.Booster}).}

\item{data}{Reference dataset. A \code{data.frame} or \code{matrix} with the same columns as in the training set of the model. Usually dataset used to train model.}

\item{...}{Additional parameters passed to the model-specific unification functions.}
}
\value{
A unified model representation - a \code{\link{model_unified.object}} object (for single-output models) or \code{\link{model_unified_multioutput.object}}, which is a list of \code{\link{model_unified.object}} objects (for multi-output models).
}
\description{
Convert your tree-based model into a standardized representation.
The returned representation is easy to be interpreted by the user and ready to be used as an argument in \code{treeshap()} function.
}
\examples{

 library(ranger)
 data_fifa <- fifa20$data[!colnames(fifa20$data) \%in\%
                            c('work_rate', 'value_eur', 'gk_diving', 'gk_handling',
                             'gk_kicking', 'gk_reflexes', 'gk_speed', 'gk_positioning')]
 data <- na.omit(cbind(data_fifa, target = fifa20$target))

 rf1 <- ranger::ranger(target~., data = data, max.depth = 10, num.trees = 10)
 unified_model1 <- unify(rf1, data)
 shaps1 <- treeshap(unified_model1, data[1:2,])
 plot_contribution(shaps1, obs = 1)

 rf2 <- randomForest::randomForest(target~., data = data, maxnodes = 10, ntree = 10)
 unified_model2 <- unify(rf2, data)
 shaps2 <- treeshap(unified_model2, data[1:2,])
 plot_contribution(shaps2, obs = 1)
}
\seealso{
\code{\link{lightgbm.unify}} for \code{\link[lightgbm:lightgbm]{LightGBM models}}

\code{\link{gpboost.unify}} for \code{\link[gpboost:gpboost]{GPBoost models}}

\code{\link{gbm.unify}} for \code{\link[gbm:gbm]{GBM models}}

\code{\link{xgboost.unify}} for \code{\link[xgboost:xgboost]{XGBoost models}}

\code{\link{ranger.unify}} for \code{\link[ranger:ranger]{ranger models}}

\code{\link{randomForest.unify}} for \code{\link[randomForest:randomForest]{randomForest models}}
}
