###############################################################################
###############################################################################
#-----------------------------------------------------------------------------#
####Author     : Kelli Faye Johnson
####Contact    : kellifayejohnson@gmail.com
####Lastupdate :
####Purpose    :
####Packages   :
####Inputs     :
####Outputs    :
####Remarks    : Character width = 80
#-----------------------------------------------------------------------------#
###############################################################################
###############################################################################

###############################################################################
## Step
## Set working directories
###############################################################################
wd.curr <- getwd()
if (Sys.info()["user"] == "kelli") devtools::load_all("c:/ss/ss3models")
setwd(system.file("cases", package = "ss3models"))
my.spp <- dir(system.file("models", package = "ss3models"))

library(ss3sim)

start <- 1
end   <- 100

start.fishery <- 26
years.rup <- 40

start.survey  <- start + 75
start.fishery <- start + 25
freq.survey  <- 2
freq.fishery <- c(10, 4)

# Information regarding sample frequency
# Amount to cut data by (e.g., if 2 take every other point)
reducer <- 2
# Number of years randomly picked for mlacomps
nmlayears <- 2
# Number of years randomly picked for calcomps
ncalyears <- 2

# Information regarding sample intensity
# Currently not using the lower sample size as Ono et al. (2014)
# showed sample size really did not matter
# lcomp and age comp sample sizes
high <- 100
low <- 10

# Estimate CVs or not
estCVs <- TRUE

###############################################################################
###############################################################################
#### Step
#### Calculate years that things happen based on inputs above
###############################################################################
###############################################################################
years.fish <- end + start - start.fishery

# Number of years the fishery ramps up before starting two way trip
all.surv <- seq(start.survey, end, by = freq.survey)
all.fish <- c(seq(start.fishery, start.fishery + 20, by = freq.fishery[1]),
              seq(start.fishery + 30, end, by = freq.fishery[2]))

less <- sapply(c("surv", "fish"), function(x) {
                realword <- paste("all", x, sep = ".")
                vals <- eval(parse(text = realword))
                vals[seq.int(1L, length(vals), reducer)]
               })

years.txt <- lapply(list(as = all.surv, af = all.fish,
  ls = less$surv, lf = less$fish), case_deparse)

###############################################################################
###############################################################################
#### Step
#### Functions to create casefiles
###############################################################################
###############################################################################
# E change_e, change parameter estimation
writeE <- function(name, int, phase, species, case) {
sink(paste0("E", case, "-", species, ".txt"))
    cat("natM_type; 1Parm \nnatM_n_breakpoints; NULL \n",
        "natM_lorenzen; NULL \n", sep = "")
    testfornatm <- grepl("NatM_p_1_Fem", name)
    if (any(testfornatm)) {
        cat("natM_val; c(", int[testfornatm], ", ", phase[testfornatm],
            ")\n", sep = "")
    } else {
      cat("natM_val; c(NA, NA) \n", sep = "")
    }
    if (all(testfornatm)) {
        cat("par_name; NULL \n", "par_int; NULL \n", "par_phase; NULL \n", sep = "")
      } else{
        cat("par_name; c(\"",
            paste0(name[!testfornatm], collapse = "\", \""), "\")\n", sep = "")
        if (all(is.na(int))) {
            cat("par_int; c(",
            paste0(int[!testfornatm], collapse = ", "), ")\n",
            "par_phase; c(",
            paste0(phase[!testfornatm], collapse = ", "), ")\n",
            sep = "")
        } else {
            cat("par_int; c(\"",
            paste0(int[!testfornatm], collapse = "\", \""), "\")\n",
            "par_phase; c(\"",
            paste0(phase[!testfornatm], collapse = "\", \""), "\")\n",
            sep = "")
        }
      }
      cat("forecast_num; 0\nrun_change_e_full; TRUE\n", sep = "")
  sink()
}

# D sample mlacomp data
writeD <- function(fleets, years, Nsamp, species, case, type = "mlacomp",
                   mean_outfile = "NULL") {
  if (is.null(fleets)) {
    a.fleet <- "NULL"
  } else {
    a.fleet <- paste0("c(", paste(fleets, collapse = ", "), ")")
  }
  a <- c(paste("fleets;", a.fleet),
         paste("years;", years),
         paste("Nsamp;", Nsamp),
         paste("mean_outfile;", mean_outfile))
  if (type == "calcomp") {
    a <- c(paste("fleets;", a.fleet), paste("years;", years),
           paste("Nsamp;", Nsamp))
  }
  writeLines(a, paste0(type, case, "-", species, ".txt"))
}

# Change selectivity to be dome or time-varying in OM
writeS <- function(vals, species, case,
                   type = c("random", "deviates")) {
  type <- match.arg(type, several.ok = FALSE)
  parnames <- paste0("SizeSel_1P_", 1:6, "_Fishery")
  beg <- paste("function_type; change_tv")
  sec <- "param;"
  mid <- "dev; rnorm(n = 100, mean = 0, sd = "
  end <- ")"
  let <- toupper(rev(letters)[1:6])
  done <- capture.output(
  lapply(seq_along(parnames), function(x) {
    if(type == "deviates") {
      info <- c(beg, paste(sec, parnames[x]),
                paste0("dev; rep(", vals[x], ", 100)"))
    } else {
      info <- c(beg, paste(sec, parnames[x]), paste0(mid, vals[x], end))
    }
    writeLines(info, paste0(let[x], case, "-", species, ".txt"))
  }))
}

# Add time-varying random normal deviates to M
writeM <- function(deviates, species, case) {
  beg <- paste("function_type; change_tv")
  sec <- "param;"
  mid <- "dev; "

  info <- c(beg, paste(sec, "NatM_p_1_Fem_GP_1"),
            paste0(mid, paste0(deviates)))
  writeLines(info, paste0("M", case, "-", species, ".txt"))
}

  # End of functions for creating case files

###############################################################################
## Step
## Sequence along all species listed in my.spp
###############################################################################
for (spp in seq_along(my.spp)) {

###############################################################################
###############################################################################
#### Step
#### Standard case files
#### These case files do not change per scenario
#### Retro and index
###############################################################################
###############################################################################
# No retrospective runs
# writeLines("retro_yr; 0", paste0("R0-", my.spp[spp], ".txt"))

# Years of survey index of abundance
writeLines(c("fleets; 2", paste0("years; list(c(",
             paste(all.surv, collapse = ","), "))"), "sds_obs; list(0.2)"),
             paste0("index0-", my.spp[spp], ".txt"))

###############################################################################
###############################################################################
#### Step
#### change_e: case "E"
###############################################################################
###############################################################################
# Switch to the below code if we want to also estimate the CV parameters
if (estCVs) {
  allgrowth <- c("L_at_Amin", "L_at_Amax", "VonBert_K", "CV_young", "CV_old")
} else {
  allgrowth <- c("L_at_Amin", "L_at_Amax", "VonBert_K")
}

growthint <- rep(NA, length(allgrowth))
growthphase <- rep(-1, length(allgrowth))
counter <- 0

# All growth parameters are fixed at their true OM values
  writeE(allgrowth, growthint, growthphase, my.spp[spp], counter)
# Create same Estimation case files but with a single forecast
  data <- readLines(paste0("E", counter, "-", my.spp[spp], ".txt"))
  data[grep("forecast", data)] <- gsub("[0-9]", "1",
    grep("forecast", data, value = TRUE))
  writeLines(data, paste0("E99", counter, "-", my.spp[spp], ".txt"))

# All parameters are estimated
  writeE(NULL, "NA", "NA", my.spp[spp], counter + 1)
# Create same Estimation case files but with a single forecast
  data <- readLines(paste0("E", counter + 1, "-", my.spp[spp], ".txt"))
  data[grep("forecast", data)] <- gsub("[0-9]", "1",
    grep("forecast", data, value = TRUE))
  writeLines(data, paste0("E99", counter + 1, "-", my.spp[spp], ".txt"))

###############################################################################
###############################################################################
#### Step
#### change_lcomp: case "L"
#### change_agecomp: case "A"
#### Both sets of casefiles are created with case_comp
#### change "type" to create length or age casefiles
#### if fishery then cpar = 2, if survey cpar = 1
###############################################################################
###############################################################################
# Length data from just a fishery for all years
case_comp(fleets = c(1), case = 10, spp = my.spp[spp],
  Nsamp = list(rep(high, length(all.fish))), years = list(all.fish),
  cpar = c(2), type = "lcomp")

# Length data for all years of fishery and survey
case_comp(fleets = c(1, 2), case = 30, spp = my.spp[spp],
  Nsamp = list(rep(high, length(all.fish)), rep(high, length(all.surv))),
  years = list(all.fish, all.surv), cpar = c(2, 1), type = "lcomp")

# Length data for all years of fishery and reduced years from survey
case_comp(fleets = c(1, 2), case = 31, spp = my.spp[spp],
  Nsamp = list(rep(high, length(all.fish)), rep(high, length(less$surv))),
  years = list(all.fish, less$surv), cpar = c(2, 1), type = "lcomp")

# No age data
case_comp(fleets = NULL, case = 0, my.spp[spp], Nsamp = NULL, years = NULL,
  cpar = NULL, type = "agecomp")

# Age data from just a fishery for all years
case_comp(fleets = c(1), case = 10, spp = my.spp[spp],
  Nsamp = list(rep(high, length(all.fish))), years = list(all.fish),
  cpar = c(2), type = "agecomp")

# Age data for all years of fishery and survey
case_comp(fleets = c(1, 2), case = 30, spp = my.spp[spp],
  Nsamp = list(rep(high, length(all.fish)), rep(high, length(all.surv))),
  years = list(all.fish, all.surv), cpar = c(2, 1), type = "agecomp")

# Age data for all years of fishery and reduced years from survey
case_comp(fleets = c(1, 2), case = 31, spp = my.spp[spp],
  Nsamp = list(rep(high, length(all.fish)), rep(high, length(less$surv))),
  years = list(all.fish, less$surv), cpar = c(2, 1), type = "agecomp")

###############################################################################
###############################################################################
#### Step
#### sample_mlacomp data: D
###############################################################################
###############################################################################
q <- c("vbgf_remove")

# No mla comp data
writeD(fleets = NULL, years = "NULL", Nsamp = "NULL",
       my.spp[spp], case = 0)

# mla comp for fishery
writeD(fleets = 1,
       years = paste0("list(sample(", years.txt$lf, ", ", nmlayears, ", replace = FALSE))"),
       Nsamp = "list(50)", my.spp[spp], case = 10, mean_outfile = q)

# mla comp for survey
writeD(fleets = 2,
       years = paste0("list(sample(", years.txt$ls, ", ", nmlayears, ",replace = FALSE))"),
       Nsamp = "list(50)", my.spp[spp], case = 20, mean_outfile = q)

###############################################################################
###############################################################################
#### Step
#### sample_calcomp data: C
#### Number of years is randomly set from ncalyears
###############################################################################
###############################################################################
# No cal comp data
writeD(fleets = NULL, years = "NULL", Nsamp = "NULL", type = "calcomp",
       my.spp[spp], case = 0)

# cal comp data for fishery
writeD(fleets = 1, type = "calcomp",
       years = paste0("list(sample(", years.txt$lf, ", ", ncalyears, ", replace = FALSE))"),
       Nsamp = "list(50)", my.spp[spp], case = 10, mean_outfile = q)

# cal comp for survey
writeD(fleets = 2, type = "calcomp",
       years = paste0("list(sample(", years.txt$ls, ", ", ncalyears, ", replace = FALSE))"),
       Nsamp = "list(50)", my.spp[spp], case = 20, mean_outfile = q)

###############################################################################
###############################################################################
#### Step
#### Close the loop for all species
###############################################################################
###############################################################################
}

###############################################################################
###############################################################################
#### Step
#### End of file
###############################################################################
###############################################################################
setwd(wd.curr)
