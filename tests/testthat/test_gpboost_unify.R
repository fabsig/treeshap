library(treeshap)
param_gpboost <- list(objective = "regression",
                       max_depth = 3,
                       force_row_wise = TRUE,
                       learning.rate = 0.1)

data_fifa <- fifa20$data[!colnames(fifa20$data)%in%c('work_rate', 'value_eur', 'gk_diving', 'gk_handling', 'gk_kicking', 'gk_reflexes', 'gk_speed', 'gk_positioning')]
data <- as.matrix(na.omit(data.table::as.data.table(cbind(data_fifa, fifa20$target))))
sparse_data <- data[,-ncol(data)]
x <- gpboost::gpb.Dataset(sparse_data, label = data[,ncol(data)])
gpb_data <- gpboost::gpb.Dataset.construct(x)
gpb_fifa <- gpboost::gpboost(data = gpb_data,
                      params = param_gpboost,
                      verbose = -1,
                      num_threads = 0)
gpbtree <- gpboost::gpb.model.dt.tree(gpb_fifa)

test_that('gpboost.unify returns an object with correct attributes', {
  unified_model <- gpboost.unify(gpb_fifa, sparse_data)

  expect_equal(attr(unified_model, "missing_support"), TRUE)
  expect_equal(attr(unified_model, "model"), "gpboost")
})

test_that('Columns after gpboost.unify are of appropriate type', {
  unified_model <- gpboost.unify(gpb_fifa, sparse_data)$model
  expect_true(is.integer(unified_model$Tree))
  expect_true(is.character(unified_model$Feature))
  expect_true(is.factor(unified_model$Decision.type))
  expect_true(is.numeric(unified_model$Split))
  expect_true(is.integer(unified_model$Yes))
  expect_true(is.integer(unified_model$No))
  expect_true(is.integer(unified_model$Missing))
  expect_true(is.numeric(unified_model$Prediction))
  expect_true(is.numeric(unified_model$Cover))
})

test_that('gpboost.unify creates an object of the appropriate class', {
  expect_true(is.model_unified(gpboost.unify(gpb_fifa, sparse_data)))
  expect_true(is.model_unified(unify(gpb_fifa, sparse_data)))
})

test_that('basic columns after gpboost.unify are correct', {
  unified_model <- gpboost.unify(gpb_fifa, sparse_data)$model
  expect_equal(gpbtree$tree_index, unified_model$Tree)
  to_test_features <- gpbtree[order(gpbtree$split_index), .(split_feature,split_index, threshold, leaf_count, internal_count),tree_index]
  expect_equal(to_test_features[!is.na(to_test_features$split_index),][['split_index']], unified_model[!is.na(unified_model$Feature),][['Node']])
  expect_equal(to_test_features[['split_feature']], unified_model[['Feature']])
  expect_equal(to_test_features[['threshold']], unified_model[['Split']])
  expect_equal(to_test_features[!is.na(internal_count),][['internal_count']], unified_model[!is.na(unified_model$Feature),][['Cover']])
})

test_that('connections between nodes and leaves after gpboost.unify are correct', {
  test_object <- as.data.table(gpboost.unify(gpb_fifa, sparse_data)$model)
  #Check if the sums of children's covers are correct
  expect_equal(test_object[test_object[!is.na(test_object$Yes)][['Yes']]][['Cover']] +
    test_object[test_object[!is.na(test_object$No)][['No']]][['Cover']], test_object[!is.na(Feature)][['Cover']])
  #check if default_left information is correctly used
  df_default_left <- gpbtree[default_left == "TRUE", c('tree_index', 'split_index')]
  test_object_actual_default_left <- test_object[Yes == Missing, c('Tree', 'Node')]
  colnames(test_object_actual_default_left) <- c('tree_index', 'split_index')
  attr(test_object_actual_default_left, 'model') <- NULL
  expect_equal(test_object_actual_default_left[order(tree_index, split_index)], df_default_left[order(tree_index, split_index)])
  #and default_left = FALSE analogically:
  df_default_right <- gpbtree[default_left != 'TRUE', c('tree_index', 'split_index')]
  test_object_actual_default_right <- test_object[No == Missing, c('Tree', 'Node')]
  colnames(test_object_actual_default_right) <- c('tree_index', 'split_index')
  attr(test_object_actual_default_right, 'model') <- NULL
  expect_equal(test_object_actual_default_right[order(tree_index, split_index)], df_default_right[order(tree_index, split_index)])
  #One more test with checking the usage of 'decision_type' column needed
})

# Function that return the predictions for sample observations indicated by vector contatining values -1, 0, 1, where -1 means
# going to the 'Yes' Node, 1 - to the 'No' node and 0 - to the missing node. The vectors are randomly produced during executing
# the function and should be passed to prepare_original_preds_ to save the conscistence. Later we can compare the 'predicted' values
prepare_test_preds <- function(unify_out){
  stopifnot(all(c("Tree", "Node", "Feature", "Split", "Yes", "No", "Missing", "Prediction", "Cover") %in% colnames(unify_out)))
  test_tree <- unify_out[unify_out$Tree %in% 0:9,]
  test_tree[['node_row_id']] <- seq_len(nrow(test_tree))
  test_obs <- lapply(table(test_tree$Tree), function(y) sample(c(-1, 0, 1), y, replace = T))
  test_tree <- split(test_tree, test_tree$Tree)
  determine_val <- function(obs, tree){
    root_id <- tree[['node_row_id']][1]
    tree[,c('Yes', 'No', 'Missing')] <- tree[,c('Yes', 'No', 'Missing')] - root_id + 1
    i <- 1
    indx <- 1
    while(!is.na(tree$Feature[indx])) {
      indx <- ifelse(obs[i] == 0, tree$Missing[indx], ifelse(obs[i] < 0, tree$Yes[indx], tree$No[indx]))
      #if(length(is.na(tree$Feature[indx]))>1) {print(paste(indx, i)); print(tree); print(obs)}
      i <- i + 1
    }
    return(tree[['Prediction']][indx])
  }
  x = numeric()
  for(i in seq_along(test_obs)) {
    x[i] <- determine_val(test_obs[[i]], test_tree[[i]])

  }
  return(list(preds = x, test_obs = test_obs))
}

prepare_original_preds_gpb <- function(orig_tree, test_obs){
  test_tree <- orig_tree[orig_tree$tree_index %in% 0:9,]
  test_tree <- split(test_tree, test_tree$tree_index)
  stopifnot(length(test_tree) == length(test_obs))
  determine_val <- function(obs, tree){
    i <- 1
    indx <- 1
    while(!is.na(tree$split_feature[indx])) {
      children <- ifelse(is.na(tree$node_parent), tree$leaf_parent, tree$node_parent)
      if((obs[i] < 0) | (tree$default_left[indx] == 'TRUE' & obs[i] == 0)){
        indx <- which(tree$split_index[indx] == children)[1]
      }
      else if((obs[i] > 0) | (tree$default_left[indx] == 'FALSE' & obs[i] == 0)) {
        indx <- which(tree$split_index[indx] == children)[2]
      }
      else{
        stop('Error in the connections')
        indx <- 0
      }
      i <- i + 1
    }
    return(tree[['leaf_value']][indx])
  }
  y = numeric()
  for(i in seq_along(test_obs)) {
    y[i] <- determine_val(test_obs[[i]], test_tree[[i]])
  }
  return(y)
}

test_that('the connections between the nodes are correct', {
  # The test is passed only if the predictions for sample observations are equal in the first 10 trees of the ensemble
  x <- prepare_test_preds(gpboost.unify(gpb_fifa, sparse_data)$model)
  preds <- x[['preds']]
  test_obs <- x[['test_obs']]
  original_preds <- prepare_original_preds_gpb(gpbtree, test_obs)
  expect_equal(preds, original_preds)
})

test_that("gpboost: predictions from unified == original predictions", {
  unifier <- gpboost.unify(gpb_fifa, sparse_data)
  obs <- c(1:16000)
  original <- stats::predict(gpb_fifa, sparse_data[obs, ])
  from_unified <- predict(unifier, sparse_data[obs, ])
  expect_equal(from_unified, original)
  #expect_true(all(abs((from_unified - original) / original) < 10**(-14))) #not needed
})

test_that("gpboost: mean prediction calculated using predict == using covers", {
  unifier <- gpboost.unify(gpb_fifa, sparse_data)

  intercept_predict <- mean(predict(unifier, sparse_data))

  ntrees <- sum(unifier$model$Node == 0)
  leaves <- unifier$model[is.na(unifier$model$Feature), ]
  intercept_covers <- sum(leaves$Prediction * leaves$Cover) / sum(leaves$Cover) * ntrees

  #expect_true(all(abs((intercept_predict - intercept_covers) / intercept_predict) < 10**(-14)))
  expect_equal(intercept_predict, intercept_covers)
})

test_that("gpboost: covers correctness", {
  unifier <- gpboost.unify(gpb_fifa, sparse_data)

  roots <- unifier$model[unifier$model$Node == 0, ]
  expect_true(all(roots$Cover == nrow(sparse_data)))

  internals <- unifier$model[!is.na(unifier$model$Feature), ]
  yes_child_cover <- unifier$model[internals$Yes, ]$Cover
  no_child_cover <- unifier$model[internals$No, ]$Cover
  if (all(is.na(internals$Missing))) {
    children_cover <- yes_child_cover + no_child_cover
  } else {
    missing_child_cover <- unifier$model[internals$Missing, ]$Cover
    missing_child_cover[is.na(missing_child_cover)] <- 0
    missing_child_cover[internals$Missing == internals$Yes | internals$Missing == internals$No] <- 0
    children_cover <- yes_child_cover + no_child_cover + missing_child_cover
  }
  expect_true(all(internals$Cover == children_cover))
})
