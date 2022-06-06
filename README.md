# Numeric Range Glob

## Motivation

Problem: Data Lake directories containing huge numbers of small timestamped
files (name follows convention: `YYYYMMDD-HHMM`). We want to read these files
using [Apache Spark](https://spark.apache.org/) but reading all the files at
once is extremely slow. So we want to read the files in chunks, but doing a list
files operation is also extremely slow.

Solution: Construct appropriate globs and pass this to Spark. For some reason,
this is substantially faster than even a list files operation.

## Background

[Glob](https://en.wikipedia.org/wiki/Glob_(programming)) is a common extension
for specifying file paths. A common use of a glob is to only read files of a
specific extension by combining the `*` wildcard with the extension, e.g.
`*.csv.gz`.

However, globs enable functionality beyond just a wildcard, in particular it can
handle ranges, e.g. `[1-3]` (1, 2, 3) or `[a-c]` (a, b, c), and alternation,
e.g. `{1,2}` (1 or 2).

This is quite powerful, though each range is limited to only a single character,
making multi-character ranges more tricky, e.g. to do 11 to 21 requires
`{1[1-9],2[0-1]}` (11 to 19, 20 to 21), or to do 11 to 55 requires
`{1[1-9],[2-4][0-9],5[0-5]}` (11 to 19, 20 to 49, 50 to 55).

We can efficiently generate multi-character numeric glob ranges using tree
logic. A use case for this is where we have files with names that include
timestamps of the form `YYYYMMDD`, where we can specify and read files within a
specific time-range by generating the appropriate glob.

## Content

This repository contains a two scripts, `globRange.R`, which contains the main
functions `globRange` and `dateRangeGlob`, and `test.R` which contains some
tests. While these are R scripts, the logic could be easily extended into other
languages.

### dateRangeGlob

`dateRangeGlob` is a wrapper to `globRange` for the date-range use case. It was
written for files of the form: `YYYYMMDD-HHMM` but works for any file that
begins with `YYYYMMDD`.

Arguments:

- `startDate`
- `endDate`
- `str_suffix` (default: `".csv.gz"` can be used to specify the file extension)

It returns the appropriate glob, e.g.

```r
> dateRangeGlob(startDate = "2020-03-24", endDate = "2020-03-29")
[1] "2020032[4-9]*.csv.gz"

> dateRangeGlob(startDate = "2020-03-24", endDate = "2020-12-31")
[1] "2020{032[4-9],03[3-9],0[4-9],1[0-1],12[0-2],123[0-1]}*.csv.gz"
```

### globRange

`globRange` is a generalised function for generating multi-character numeric
glob ranges.

One way to think of the problem systematically is to use a branching tree (like
a decision tree).

Consider the following range, 1234 - 4321. The tree looks like this:

- `1`
    - `2`
        - `3`
            - `[4-9]`
        - `[4-9]`
    - `[3-9]`
- `[2-3]`
- `4`
    - `[0-2]`
    - `3`
        - `[0-1]`
        - `2`
            - `[0-1]`

To get the final glob, we follow along each branch and concatenate, e.g. the top
branch becomes `123[4-9]`, then the next is `12[4-9]`, etc. All the branches
together (which can be combined using alternation) form the necessary glob to
capture the range 1234 - 4321.

Consider the following range, 20200324 - 20201231. The first 4 characters are
the same, so we're really only interested from the 5th character. From here, the
tree looks like this:

- `0`
    - `3`
        - `2`
            - `[4-9]`
        - `[3-9]`
    - `[4-9]`
- `1`
    - `[0-1]`
    - `2`
        - `[0-2]`
        - `3`
            - `[0-1]`

To get the final glob, we follow along each branch and concatenate, e.g. the top
branch becomes `032[4-9]`, then the next is `03[3-9]`, etc. To finish the glob,
we prepend the characters that are the same and use alternation to combine the
branches together, this becomes
`2020{032[4-9],03[3-9],0[4-9],1[0-1],12[0-2],123[0-1]}`.

Let's break-down how this tree works. There are three types of branches in this
tree:

1. Initial branch
2. Upper branches
3. Lower branches

For the Upper and Lower branches, the final character is a special case as the
branches terminates there.

Let's suppose we have the numeric range 1234 - 4321. We take these two numbers
as strings, the `start_str` and `end_str` respectively. The initial branch
occurs at the first character where the two strings differ, for our range this
is from character 1.

- `1` (initial lower)
- `[2-3]` (initial between)
- `4` (initial upper)

The initial lower captures the lower-bound of our range, and begins the lower
branch. Likewise, the initial upper captures the upper-bound and begins the
upper branch. The initial between captures anything in-between.

For both the lower and upper branch, we iterate along the start/end string from
the initial lower/upper, at each node having 2 branches, except for the final
character which has a single branch.

Let's take the initial lower as our example. The next character in `start_str`
is `2`. The two branches are:

- `2` (lower-end)
    - ... (to do in next iteration)
- `[3-9]` (upper-end)

As we already know from the initial branch that the previous character was
different, and that this is the lower branch, we can do a broad `[3-9]` range to
capture the upper-end of this lower branch. The lower-end however needs a bit
more effort and more iterations. The next character in `start_str` is `3`, so
the two branches are:

- `3` (lower-end)
    - ... (to do in next iteration)
- `[4-9]` (upper-end)

The exact same process as before gives us our branches, and again the lower-end
requires another iteration. The next character in `start_str` is `4`, but as
it's the final character we only have one branch:

- `[4-9]` (final character)

As we know there are no further characters to process, we can handle everything
with a single range. When combined with the parent nodes, this branch forms the
following glob: `123[4-9]`, which captures the range 1234 - 1239. Let's go back
up another iteration:

- `3` (lower-end)
    - `[4-9]` (final character)
- `[4-9]` (upper-end)

These two branches capture the ranges: 1234 - 1239 and 1240 - 1299. Going up to
the initial lower to view the entire lower branch:

- `1` (initial lower)
    - `2` (lower-end)
        - `3` (lower-end)
            - `[4-9]` (final character)
        - `[4-9]` (upper-end)
    - `[3-9]` (upper-end)

These three branches capture the ranges: 1234 - 1239, 1240 - 1299 and 1300 -
1999.

The initial between captures the range 2000 - 3999.

The same process applies to the upper branch, but noting that the direction is
flipped, e.g. the second character of the `end_str` is `3`, so the two branches
are:

- `[0-2]` (lower-end)
- `3` (upper-end)
    - ... (to do in next iteration)

As this is the upper branch, the lower-end captures a range while the upper-end
requires further resolution. The full upper branch is:

- `4` (initial upper)
    - `[0-2]` (lower-end)
    - `3` (upper-end)
        - `[0-1]` (lower-end)
        - `2` (upper-end)
            - `[0-1]` (final character)

These three branches capture the ranges: 4000 - 4299, 4300 - 4319 and 4320 -
4321.

The resulting 7 branches of the full tree thus captures all the ranges necessary
to capture the multi-character numeric range 1234 - 4321.

N.B. These globs use a "lazy" finish with a wildcard `*`, e.g. `4[0-2]*` is
assumed to capture the range 4000 - 4299 because we assume the filenames conform
to a numeric sequence of equal length. Where such an assumption does not hold,
the function could be modified to be more strict with its glob generation e.g.
by generating `4[0-2][0-9][0-9]`, which would exactly capture 4000 - 4299 at the
expense of being more verbose.
