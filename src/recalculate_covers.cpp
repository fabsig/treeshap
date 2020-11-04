#include <Rcpp.h>
using namespace Rcpp;

// [[Rcpp::plugins(cpp11)]]

// [[Rcpp::export]]
IntegerVector new_covers(DataFrame x, DataFrame is_na, IntegerVector roots, IntegerVector yes, IntegerVector no,
                         IntegerVector missing, LogicalVector is_leaf, IntegerVector feature, NumericVector split) {
  IntegerVector cover(is_leaf.size());
  for (int i = 0; i < x.ncol(); ++i) {
    NumericVector observation = x[i];
    NumericVector observation_is_na = is_na[i];

    for (int node: roots) {
      while (!is_leaf[node]) {
        cover[node]++;

        if (observation_is_na[feature[node]]) {
          node = missing[node];
        } else if (observation[feature[node]] <= split[node]) {
          node = yes[node];
        } else {
          node = no[node];
        }
      }
      cover[node]++;
    }
  }

  return cover;
}
