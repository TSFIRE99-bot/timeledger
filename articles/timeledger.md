# Getting started with timeledger

``` r

library(timeledger)
```

## The problem in 100 minutes

A recording lasts 100 minutes and has a complete reference. True atrial
fibrillation (AF) occurs on \[10, 20) and \[40, 60). A detector flags
\[10, 20) and \[70, 80), abstains on \[40, 60), and answers “no AF” the
rest of the time.

How good is it? That depends on which question you ask. On the time it
answered, it found all the AF it saw. Over the whole recording, it found
a third of the AF. One of its two alarms was false. All of these are
correct statements, and a single sensitivity number hides which one is
being made.

``` r

fx <- tl_fixture("acceptance")
fx$reference
#>   record start end  label
#> 1   rec1     0  10 non-AF
#> 2   rec1    10  20     AF
#> 3   rec1    20  40 non-AF
#> 4   rec1    40  60     AF
#> 5   rec1    60 100 non-AF
fx$predictions
#>   record detector start end response             reason
#> 1   rec1        D     0  10 negative               <NA>
#> 2   rec1        D    10  20 positive               <NA>
#> 3   rec1        D    20  40 negative               <NA>
#> 4   rec1        D    40  60  abstain low signal quality
#> 5   rec1        D    60  70 negative               <NA>
#> 6   rec1        D    70  80 positive               <NA>
#> 7   rec1        D    80 100 negative               <NA>
```

## One table of time

[`tl_ledger()`](https://tsfire99-bot.github.io/timeledger/reference/tl_ledger.md)
splits the recording at every point where the reference, the input
status or the detector’s response changes. The pieces are half-open
intervals that never overlap.

``` r

led <- tl_ledger(fx$records, fx$reference, fx$predictions,
                 event = "AF", time_unit = "min")
led
#> <tl_ledger> 7 rows | 1 record(s) | detector(s): D | time unit: min
#>  record detector start end reference observation response    response_reason
#>    rec1        D     0  10  nonevent     unknown negative               <NA>
#>    rec1        D    10  20     event     unknown positive               <NA>
#>    rec1        D    20  40  nonevent     unknown negative               <NA>
#>    rec1        D    40  60     event     unknown  abstain low signal quality
#>    rec1        D    60  70  nonevent     unknown negative               <NA>
#>    rec1        D    70  80  nonevent     unknown positive               <NA>
#>    rec1        D    80 100  nonevent     unknown negative               <NA>
tl_check(led)
#>   record detector target ledger contiguous starts_at_target   ok
#> 1   rec1        D    100    100       TRUE             TRUE TRUE
```

Each row records what we knew about one stretch of time. Four kinds of
response get their own label, because they are easy to lump together by
mistake:

- `negative`: the detector answered “no event”, and can be right or
  wrong;
- `abstain`: input was available and the detector declined to answer;
- `no_input`: the monitor had no input, so no answer was possible;
- `unknown`: there is no prediction row and its meaning was not
  declared.

The reference column is `event`, `nonevent` or `unknown`. Unknown
reference time is left out of every denominator that needs the truth.

A missing row is easy to misread. In the next chunk we delete the last
row, which leaves minutes 80 to 100 without a prediction. The ledger
marks them `"unknown"`; they would count as negatives only if `missing`
said so:

``` r

gap <- fx$predictions[-7, ]    # drop the last row: [80, 100) is now uncovered
led_gap <- tl_ledger(fx$records, fx$reference, gap, time_unit = "min")
tl_trace(led_gap, "rec1", 75, 100)[, c("start", "end", "response",
                                       "response_source")]
#>   start end response           response_source
#> 1    70  80 positive                prediction
#> 2    80 100  unknown declared missing: unknown
```

## Metrics carry their denominators

``` r

m <- tl_match(led, policy = "one_to_one")
met <- tl_metrics(led, m, level = "pooled")
met[met$metric %in% c("answer_coverage", "answered_sensitivity",
                      "full_capture", "episode_sensitivity",
                      "false_alarms_per_answered_hour",
                      "pred_burden_answered", "ref_burden_answered",
                      "burden_bound_lower", "burden_bound_upper"),
    c("metric", "estimate", "numerator", "denominator", "unit")]
#>                          metric estimate numerator denominator       unit
#>                 answer_coverage   0.8000        80         100 proportion
#>            answered_sensitivity   1.0000        10          10 proportion
#>                    full_capture   0.3333        10          30 proportion
#>             episode_sensitivity   0.5000         1           2 proportion
#>  false_alarms_per_answered_hour   0.7500         1          80   per hour
#>            pred_burden_answered   0.2500        20          80 proportion
#>             ref_burden_answered   0.1250        10          80 proportion
#>              burden_bound_lower   0.2000        20         100 proportion
#>              burden_bound_upper   0.4000        40         100 proportion
```

The burden bounds say that if the abstained 20 minutes were filled in,
the full-period predicted burden could be anywhere from 20% to 40%. That
bounds the prediction, not the true burden.

The missed AF is broken down by why it was missed:

``` r

met[grepl("^missed_", met$metric), c("metric", "estimate", "unit")]
#>               metric estimate    unit
#>  missed_negative_min        0 minutes
#>   missed_abstain_min       20 minutes
#>  missed_no_input_min        0 minutes
#>   missed_unknown_min        0 minutes
```

## Every number can be traced

``` r

m$alarms[, c("alarm_id", "start", "end", "status", "episode_id")]
#>      alarm_id start end  status episode_id
#> 1 rec1:D:a001    10  20 matched  rec1:e001
#> 2 rec1:D:a002    70  80   false       <NA>
fa <- m$alarms$alarm_id[m$alarms$status == "false"]
tl_explain(led, m, alarm = fa)[, c("start", "end", "reference", "response",
                                   "decision")]
#>   start end reference response decision
#> 1    70  80  nonevent positive    false
tl_explain(led, m, episode = "rec1:e002")[, c("start", "end", "response",
                                              "response_reason")]
#>   start end response    response_reason
#> 1    40  60  abstain low signal quality
```

## Matching is a named choice

``` r

fx2 <- tl_fixture("acceptance")
fx2$predictions <- data.frame(record = "rec1", detector = "D",
                              start = c(0, 15, 50), end = c(15, 50, 100),
                              response = c("negative", "positive", "negative"))
led2 <- tl_ledger(fx2$records, fx2$reference, fx2$predictions, time_unit = "min")
one <- tl_metrics(led2, tl_match(led2, policy = "one_to_one"), "pooled")
any <- tl_metrics(led2, tl_match(led2, policy = "any_overlap"), "pooled")
c(one_to_one = one$estimate[one$metric == "episode_sensitivity"],
  any_overlap = any$estimate[any$metric == "episode_sensitivity"])
#>  one_to_one any_overlap 
#>         0.5         1.0
```

One long alarm spans both episodes. Under the one-to-one rule it detects
one of them; under the any-overlap rule (the rule of WFDB `epicmp`) it
detects both.

## Burden can be right for the wrong reason

``` r

bm <- tl_fixture("burden_mismatch")
led3 <- tl_ledger(bm$records, bm$reference, bm$predictions, time_unit = "min")
tl_get(tl_metrics(led3), c("burden_error_min", "full_capture"))[
  , c("metric", "estimate")]
#>             metric estimate
#> 1     full_capture        0
#> 2 burden_error_min        0
```

Here the detector flags exactly as many AF minutes as there were, so the
burden error is zero. None of the flagged minutes is a real AF minute.

## Not only AF

The engine knows nothing about AF. For seizures, apneas or any other
yes/no event, pass your own label as `event`.

``` r

seiz <- tl_ledger(tl_records("eeg1", 0, 3600),
                  data.frame(record = "eeg1", start = c(0, 1200, 1260),
                             end = c(1200, 1260, 3600),
                             label = c("bckg", "seiz", "bckg")),
                  data.frame(record = "eeg1", detector = "model",
                             start = c(0, 1230, 1300), end = c(1230, 1300, 3600),
                             response = c("negative", "positive", "negative")),
                  event = "seiz")
tl_get(tl_metrics(seiz, tl_match(seiz)), c("full_capture", "episode_sensitivity"))[
  , c("metric", "estimate", "numerator", "denominator")]
#>                metric estimate numerator denominator
#> 1        full_capture      0.5        30          60
#> 2 episode_sensitivity      1.0         1           1
```
