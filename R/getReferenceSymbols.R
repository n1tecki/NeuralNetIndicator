#' Accessing stock price data
#'
#' Accessing and downloading of stock prices. The package allows an easy way to
#' download reference stock prices into a xts object. \cr
#' The resulting object is configured to create compatible input for the \code{\link{walkForwardNeuralnet}} function.
#'
#' All price data is downloaded from Yahoo Finance.
#'
#' @param x a list of strings containing the stock symbols of the traded asset at focus
#' as well as stock symbols relevant to the traded asset
#' @param start_date a string containing the start date of the data to be collected, expected in yyyy-mm-dd format
#' @param end_date a string containing the end date of the data to be collected, expected in yyyy-mm-dd format
#' @param focus a string that determines which one value from each stock to export into the resulting xts. \cr
#' 'op'- opening prices, 'hi'- high prices, 'lo'- low prices, 'cl' - closing prices,  'vol'- volume, 'ad'- adjusted closing prices
#' @param currency a string containing a currency code. It converts the stock prices into the desired currency
#' @param leverage a numerical value by which all asset prices are multiplied with, for example when trading with leverage
#'
#' @return xts file with one price value per day of the traded stock and all reference assets.
#'
#' @export
#'
#' @import FinancialInstrument
#' @import xts
#' @import zoo
#'
#' @examples
#' getReferenceSymbols(x = c('XOM','BP','COP','OXY','VLO','TOT','SLB'), start_date = '2000-10-10', end_date = '2020-10-10')


getReferenceSymbols <- function(x, start_date, end_date, focus = 'cl', currency = 'USD',
                                leverage = 1) {


  # PRESETTING ------------------
  options('getSymbols.warning4.0' =  FALSE)
  currency(currency)
  adjustment <- TRUE
  Sys.setenv(TZ = 'UTC')

  focus_list <- c('op','hi','lo','cl','vol','ad')
  focus <- which(grepl(focus, focus_list))
  # -----------------------------


  all_symbols <- function() {
    symbols <- x
  }


  symbols <- all_symbols()


  # Downloading stock data
  suppressWarnings(
  getSymbols(Symbols = symbols,
             src = "yahoo",
             index.class = "POSIXct",
             from = start_date,
             to = end_date,
             adjust = adjustment)
  )


  # Setting currency / multiplying leverage
  stock(symbols,
        currency = currency,
        multiplier = leverage)


  reference_symbols <- xts(order.by=index(eval(parse(text = x[1]))))   # Creating new empty xts
  # saving all focus stock prices of all symbols into xts object
  for (i in symbols) {
    reference_symbols <- merge.xts(reference_symbols,eval(parse(text = i))[,focus])
  }

  return(reference_symbols)

}
