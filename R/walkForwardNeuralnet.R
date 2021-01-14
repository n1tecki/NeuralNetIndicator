#' Calculation of oscillating trading indicator
#'
#' The \code{\link{walkForwardNeuralnet}} function takes prices
#' of multiple stocks (preferably of the same financial sector).\cr
#' Based on those reference stock prices, an indicator is calculated using price forecasts.\cr
#' The forecasts are calculated by an artificial neural network using walk-forward training over the price data.\cr
#' Thereby Z-score normalization is applied on every in-sample calibration, feeding the neural networks\cr
#' training function with the normalized prices. The trained model is then applied on the out-of-sample
#' prices,\cr before re-calibrating the model anew.
#'
#' Further information about input parameters \strong{algorithm}, \strong{stepmax}, \strong{threshold},
#' \strong{rep}, \strong{learningrate.limit}, \strong{learningrate.factor} and \strong{learningrate}
#' can be found at the \code{\link{neuralnet}} function documentation.
#'
#' @param symbols a xts/zoo/matrix object or data frame containing all reference asset prices, with each column containing
#' \strong{one} price type (opening-price/high-price/low-price/closing-price/...). Time-steps and time-intervals
#' must be identical with all stock prices. Such a xts object can be simply created using this package's
#' \code{\link{getReferenceSymbols}} function.
#' @param trad_col a numerical value or string, that points to the column containing asset prices of interest
#' in \strong{symbols}. The price predictions and indicator are made for the selected prices.
#' @param neurons_int an integer or vector of integers setting the number of neurons (vertices) in each layer.
#' @param in_sample a numerical value that sets the size of the in-sample window size of the walk-forward training.
#' @param in_sample a numerical value that sets the size of the out-of-sample window size of the
#' walk-forward training.
#' @param slid a numerical value that sets how many time-steps into the future the price should be calculated.
#' @param smooth a character string indicating the kind of smoother required that is used to smooth the indicator
#' values; '3RS3R', '3RSS', '3RSR', '3R', '3' and 'S' are possible. Default is 3R.
#' More information on the \code{\link{smooth}} function documentation
#' @param algorithm a string containing the algorithm type to calculate the neural network.
#' The following types are possible:
#' \itemize{
#'    \item 'backprop'
#'    \item 'rprop+'
#'    \item 'rprop-'
#'    \item 'sag'
#'    \item 'slr'
#' }
#' 'backprop' refers to backpropagation, 'rprop+' and 'rprop-' refer to the resilient backpropagation
#' with and without weight backtracking, while 'sag' and 'slr' induce the usage of the modified globally
#' convergent algorithm (grprop).
#' @param stepmax the maximum steps for the training of the neural network. Reaching this maximum leads
#' to a stop of the neural network's training process.
#' @param threshold a numeric value specifying the threshold for the partial derivatives of the error function
#' as stopping criteria.
#' @param rep the number of repetitions for the neural network's training.
#' @param learningrate.limit a vector or a list containing the lowest and highest limit for the learning rate.
#' Used only for RPROP and GRPROP.
#' @param learningrate.factor a vector or a list containing the multiplication factors for the upper and
#' lower learning rate. Used only for RPROP and GRPROP
#' @param learningrate a numeric value specifying the learning rate used by traditional backpropagation.
#' Used only for traditional backpropagation.
#'
#'
#' @return xts file with 3 columns - the prices of the traded stock, the related price forecasts and the
#' indicator values for each trading day
#'
#' @export
#'
#' @import neuralnet
#' @import stats
#'
#' @examples
#' walkForwardNeuralnet(symbols, trad_col=1, neurons_int = c(3,5), in_sample = 700, out_sample = 60, slid = 4)



walkForwardNeuralnet <- function(symbols, trad_col, neurons_int, in_sample, out_sample, slid = 3, algorithm = 'rprop+',
                                 smooth = '3R', stepmax = 1e+05, threshold = 0.5, rep = 2, learningrate.limit = NULL,
                                 learningrate.factor = list(minus = 0.5, plus = 1.2), learningrate = NULL) {


  symbols <- na.omit(symbols)


  focus_start <- 0
  init_bool <- TRUE


  # Walking-Forward loop calibrating NN
  while (focus_start <= nrow(symbols)-(in_sample+out_sample)) {


    # Training NN --------------
    if (init_bool) {init_index <- 1} else {init_index <- 0}   # Change value after initial loop
    features_in_sample <- symbols[focus_start:(focus_start+(in_sample-slid)),]
    predictions_in_sample <- symbols[(focus_start+(slid+init_index)):(focus_start+in_sample), trad_col]
    init_bool <- FALSE


    training <- data.frame(features_in_sample,predictions_in_sample) # Creating training data frame
    norm_training <- scale(training)   # Z-score Normalization


    # Creating feature-label like formula for NN training of all available features
    column_names <- colnames(norm_training)
    f <- paste(paste(colnames(norm_training)[trad_col], "~", sep=""),
               paste(column_names[!column_names %in% colnames(norm_training)[ncol(norm_training)]],
                     collapse = "+"))


    # Training of neural net
    nn <- neuralnet(f, data = norm_training, hidden = neurons_int, threshold = threshold,
                    stepmax = stepmax, rep = rep, startweights = NULL,learningrate.limit = learningrate.limit,
                    learningrate.factor = learningrate.factor, learningrate = learningrate,
                    lifesign = "minimal", lifesign.step = 10000, algorithm = algorithm,
                    err.fct = "sse", act.fct = "logistic", linear.output = TRUE,
                    exclude = NULL, constant.weights = NULL, likelihood = FALSE)
    # --------------------------


    # Applying NN on new data --
    features_out_sample <- symbols[(focus_start+(in_sample+1)):(focus_start+(in_sample+out_sample)),]


    aply_nn <- data.frame(features_out_sample)
    norm_aply_nn <- scale(aply_nn)   # Z-score Normalization


    nn_predict <- compute(nn,norm_aply_nn)   # Applying NN on new data
    predict_results <- nn_predict$net.result


    forecast <- t(apply(predict_results,1,
                        function(r) r * attr(norm_aply_nn, 'scaled:scale') +
                          attr(norm_aply_nn, 'scaled:center')))
    forecast <- forecast[,trad_col]
    # --------------------------


    # Results into xts ---------
    if (exists('results')) {

      results_add <- features_out_sample[,trad_col]
      results_add$forecast <- forecast
      results <- rbind(results, results_add)

    } else {

      results <- features_out_sample[,trad_col]
      results$forecast <- forecast

    }
    # --------------------------


    focus_start <- focus_start + out_sample   # Walking Forward

  }


  # Calculating the indicator
  for(i in 1:length(results[,1])) {
    results$indicator[i] <- ((results$forecast[i]-results[i,1])/results[i,1]) * 100
  }


  # Smoothing the indicator values
  if (!is.null(smooth)) {
    results$indicator <- smooth(results$indicator, kind = smooth)
  }


  return(results)

}
