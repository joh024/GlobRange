globRange = local({
  ## globRange
  ## A generalised function for generating multi-character numeric
  ##  glob ranges. When given two numeric values as strings (assumed
  ##  to be of equal length), "start_str" and "end_str", along with
  ##  the position when these two strings first differ, this function
  ##  returns the appropriate collection of globs to capture this
  ##  numeric range as a vector.
  ## Used by: `dateRangeGlob`
  ## Arguments:
  ## - start_str: A numeric value as string, e.g. "1234"
  ## - end_str: A numeric value as string, e.g. "4321"
  ##            The numeric value must be larger than start_str and
  ##              the strings must be of equal length
  ## - pos: The character position when "start_str" and "end_str" are
  ##        first different. This can be calculated using:
  ##        match(FALSE, substring(start_str, 1, 1:len_str) ==
  ##                     substring(end_str, 1, 1:len_str))
  ##        where len_str = nchar(start_str) = nchar(end_str)
  ## Returns: A vector of globs

  ##########################
  ## Supporting Functions ##
  ##########################
  ## globCore is used to handle the lower and upper branches
  ##  iteratively using recursion.
  ## See accompanying docs for more explanations.
  globCore = function(xstr, pos, is_upper){
    len_str = nchar(xstr)
    last_x = substr(xstr, pos - 1, pos - 1)
    cur_x = as.numeric(substr(xstr, pos, pos))
    if(pos == len_str){
      ## If final character, can do a simple (single-character) range
      paste0(last_x, parseRange(c(cur_x, ifelse(is_upper, 0, 9))))
    } else{
      inner = c(
        globCore(xstr, pos + 1, is_upper),
        if(is_upper){
          if(cur_x > 0) parseRange(c(cur_x - 1, 0))
        } else{
          if(cur_x < 9) parseRange(c(cur_x + 1, 9))
        }
      )
      paste0(last_x, inner)
    }
  }
  globLower = function(xstr, pos) globCore(xstr, pos, FALSE)
  globUpper = function(xstr, pos) globCore(xstr, pos, TRUE)

  parseRange = function(x)
    if(min(x) == max(x))
      min(x)
    else
      paste0("[", min(x), "-", max(x), "]")

  ###################
  ## Main function ##
  ###################
  function(start_str, end_str, pos){
    len_str = nchar(start_str)
    n_lower = as.numeric(substr(start_str, pos, pos))
    n_upper = as.numeric(substr(end_str, pos, pos))

    if(pos == len_str){
      ## If only the final character is different,
      ##   can do a simple (single-character) range
      parseRange(c(n_lower, n_upper))
    } else{
      ## Handle initial branch, then use `globCore` to handle the
      ##  following upper and lower branches
      n_between = if(n_upper - n_lower > 1)
        parseRange(c(n_lower + 1, n_upper - 1))
      c(
        globLower(start_str, pos + 1),
        n_between,
        rev(globUpper(end_str, pos + 1))
      )
    }
  }
})

dateRangeGlob =
  ## A wrapper to `globRange` for the date-range use case.
  ## Suitable for any file that begins with `yyyymmdd`.
  ## Arguments:
  ## - startDate/endDate: Dates, or characters of format %Y-%m-%d
  ## - str_suffix: Usually used to specify the file extension
  ## Returns: Appropriate glob
  function(startDate, endDate, str_suffix = "*.csv.gz"){
    ## Parse Dates
    if(class(startDate) != "Date")
      startDate = as.Date(startDate)
    if(class(endDate) != "Date")
      endDate = as.Date(endDate)

    ## Checks
    if(endDate < startDate)
      stop("Require: endDate >= startDate")

    ## Convert Dates to string
    startDate_str = format(startDate, "%Y%m%d")
    endDate_str = format(endDate, "%Y%m%d")

    ## Fringe case of start = end
    if(endDate == startDate)
      return(paste0(startDate_str, str_suffix))

    ## Compute
    len_str = nchar(startDate_str)
    pos_mismatch = match(FALSE, substring(startDate_str, 1, 1:len_str) ==
                                substring(endDate_str, 1, 1:len_str))
    str_prefix = substr(startDate_str, 1, pos_mismatch - 1)
    str_meat = globRange(startDate_str, endDate_str, pos_mismatch)
    if(length(str_meat) > 1)
      str_meat = paste0("{", paste(str_meat, collapse = ","), "}")

    ## Return
    paste0(str_prefix, str_meat, str_suffix)
  }
