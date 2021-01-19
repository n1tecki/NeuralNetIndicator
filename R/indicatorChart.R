#' Plotting financial indicator charts
#'
#' Tool to create financial charts of indicators and stock price data.
#'
#' @param indicator an xts/zoo object of a time series containing singular values for each time interval
#' @param symbol a string containing the related stock code of the indicator. Plots the stock price data
#' aligned to the corresponding indicator values.
#' @param zoom a string containing the start and end-point of the enhancement of the chart,
#' see Details for formatting information.
#'
#' The correct string format for the zoom is genrally yyyy-mm-dd::yyyy-mm-dd. However it can also be simplified to
#' yyyy-mm::yyyy-mm, yyyy::yyyy or any combination of those versions.
#'
#' @export
#'
#' @import quantmod
#'
#' @examples indicatorChart(indicator$indicator)
#' indicatorChart(indicator$indicator, symbol = 'XOM', zoom = '2018-07-01::2019-07-30')
#' indicatorChart(indicator$indicator, zoom = '2018-07-01::2019-07-30')
#' indicatorChart(indicator$indicator, symbol = 'XOM')

indicatorChart <- function(indicator, symbol=NULL, zoom=NULL) {


  if(!is.null(zoom)){
    NeuralNetIndicator <- indicator[zoom,]
  } else {
    NeuralNetIndicator <- indicator
  }


  start_date <- min(index(NeuralNetIndicator))
  end_date <- max(index(NeuralNetIndicator))


  # Indicator + stock prices
  if(!is.null(symbol)) {

    getSymbols(Symbols = symbol,
               src = "yahoo",
               index.class = "POSIXct",
               from = start_date,
               to = end_date,
               adjust = TRUE)

    if(!is.null(zoom)){
      stock <- eval(parse(text = symbol))[zoom,1:4]
    } else {
      stock <- eval(parse(text = symbol))[,1:4]
    }

    chartSeries(stock, name = symbol)

    plot(addTA(NeuralNetIndicator,col='orange', type='h'))

  } else {

    # Indicator
    lineChart(NeuralNetIndicator,theme = chartTheme("black", up.col='orange'), line.type='h')

  }

}
