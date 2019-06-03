
# Bathymetry


# Spatial interpolation using stmv
# Total "superhighres": 2-5 GB/process and 4 GB in parent for fft
# gam method requires more ~ 2X
# boundary def takes too long .. too much data to process -- skip
# "highres": ~ 20 hr with 8, 3.2 Ghz cpus on thoth using fft method jc: 2016 or 2~ 6 hr on hyperion
# "superhighres" fft: looks to be the best in performance/quality; req ~5 GB per process req
# FFT is the method of choice for speed and ability to capture the variability
# krige method is a bit too oversmoothed, especially where rapid changes are occuring


# 30 hrs
scale_ram_required_main_process = 1 # GB twostep / fft
scale_ram_required_per_process  = 1 # twostep / fft /fields vario ..  (mostly 0.5 GB, but up to 5 GB)
scale_ncpus = min( parallel::detectCores(), floor( (ram_local()- scale_ram_required_main_process) / scale_ram_required_per_process ) )

# 54 hrs
interpolate_ram_required_main_process = 4 # GB twostep / fft
interpolate_ram_required_per_process  = 8 # twostep / fft /fields vario ..
interpolate_ncpus = min( parallel::detectCores(), floor( (ram_local()- interpolate_ram_required_main_process) / interpolate_ram_required_per_process ) )

p = aegis.bathymetry::bathymetry_parameters(
  project.mode="stmv",
  data_root = project.datadirectory( "aegis", "bathymetry" ),
  DATA = 'bathymetry.db( p=p, DS="stmv.inputs" )',
  spatial.domain = "canada.east.superhighres",
  spatial.domain.subareas = c( "canada.east.highres", "canada.east",  "SSE", "SSE.mpa" , "snowcrab"),
  pres_discretization_bathymetry = 0.2 / 10,  # 0.2==p$pres; controls resolution of data prior to modelling (km .. ie 20 linear units smaller than the final discretization pres)
  stmv_dimensionality="space",
  variables = list(Y="z"),  # required as fft has no formulae
  stmv_global_modelengine = "none",  # too much data to use glm as an entry into link space ... use a direct transformation
  stmv_global_modelformula = "none",  # only marginally useful .. consider removing it and use "none",
  stmv_global_family ="none",
  stmv_local_modelengine="fft",
  stmv_fft_filter = "lowpass_matern_tapered", #  act as a low pass filter first before matern .. depth has enough data for this. Otherwise, use:
  stmv_lowpass_nu = 0.5,
  stmv_lowpass_phi = 0.1,  # p$pres = 0.2
  stmv_range_correlation_fft_taper = 0.5,  # in local smoothing convolutions occur of this correlation scale
  depth.filter = FALSE,  # need data above sea level to get coastline
  stmv_Y_transform =list(
    transf = function(x) {log10(x + 5000)} ,
    invers = function(x) {10^(x - 5000)}
  ), # data range is from -1667 to 5467 m: make all positive valued
  stmv_rsquared_threshold = 0.75, # lower threshold
  stmv_distance_statsgrid = 5, # resolution (km) of data aggregation (i.e. generation of the ** statistics ** )
  stmv_distance_scale = c(10, 15, 20, 25), # km ... approx guess of 95% AC range
  stmv_distance_prediction_fraction = 4/5, # i.e. 4/5 * 5 = 4 km
  stmv_nmin = 500,  # min number of data points req before attempting to model in a localized space
  stmv_nmax = 1000, # no real upper bound.. just speed
  stmv_clusters = list( scale=rep("localhost", scale_ncpus), interpolate=rep("localhost", interpolate_ncpus) )  # ncpus for each runmode
)


if (0) {  # model testing
  # if resetting data for input to stmv run this or if altering discretization resolution
  bathymetry.db( p=p, DS="stmv.inputs.redo" )  # recreate fields for .. requires 60GB+

  o = bathymetry.db( p=p, DS="stmv.inputs" )  # create fields for
  B = o$input
  p$stmv_global_modelformula = formula(z ~ 1)
  p$stmv_global_family= gaussian("log")
  p = stmv_variablelist(p=p)  # decompose into covariates, etc
  #  ii = which( is.finite (rowSums(B[ , c(p$variables$Y,p$variables$COV) ])) )
  # wgts = 1/B$b.sdTotal[ii]
  # wgts = wgts / mean(wgts)
  global_model = try( gam( formula=p$stmv_global_modelformula, data=B, #B[ii,],
      optimizer= p$stmv_gam_optimizer, family=p$stmv_global_family) ) #, weights=wgts ) )
  summary( global_model )
  plot(global_model, all.terms=TRUE, trans=bio.snowcrab::inverse.logit, seWithMean=TRUE, jit=TRUE, rug=TRUE )
}

# runmode=c( "globalmodel", "scale", "interpolate", "interpolate_boost", "interpolate_force_complete", "save_completed_data")
# runmode=c( "interpolate", "interpolate_boost", "save_completed_data")
stmv( p=p, runmode=runmode )  # This will take from 40-70 hrs, depending upon system
p0 = p  # store in case needed in a debug


# bring together stats and predictions and any other required computations: slope and curvature
# and then regrid/warp as the interpolation process is so expensive, regrid/upscale/downscale based off the above run
# .. still uses about 30-40 GB as the base layer is "superhighres" ..
# if parallelizing .. use different servers than local nodes
bathymetry.db( p=p, DS="complete.redo" ) # finalise at diff resolutions 15 min ..
bathymetry.db( p=p, DS="baseline.redo" )  # coords of areas of interest ..filtering of areas and or depth to reduce file size, in planar coords only


# a few plots :
pb = aegis.bathymetry::bathymetry_parameters( project.mode="stmv", spatial.domain="canada.east.highres" )
bathymetry.figures( p=pb, varnames=c("z", "dZ", "ddZ", "b.ndata", "b.range"), logyvar=TRUE, savetofile="png" )
bathymetry.figures( p=pb, varnames=c("b.sdTotal", "b.sdSpatial", "b.sdObs"), logyvar=FALSE, savetofile="png" )


pb = aegis.bathymetry::bathymetry_parameters( project.mode="stmv", spatial.domain="canada.east.superhighres" )
bathymetry.figures( p=pb, varnames=c("z", "dZ", "ddZ", "b.ndata", "b.range"), logyvar=TRUE, savetofile="png" )
bathymetry.figures( p=pb, varnames=c("b.sdTotal", "b.sdSpatial", "b.sdObs"), logyvar=FALSE, savetofile="png" )


pb = aegis.bathymetry::bathymetry_parameters( project.mode="stmv", spatial.domain="snowcrab" )
bathymetry.figures( p=pb, varnames=c("z", "dZ", "ddZ", "b.ndata", "b.range"), logyvar=TRUE, savetofile="png" )
bathymetry.figures( p=pb, varnames=c("b.sdTotal", "b.sdSpatial", "b.sdObs"), logyvar=FALSE, savetofile="png" )



### -----------------------------------------------------------------
# to recreate new polygons, run the following:
bathyclines.redo = FALSE
depthsall = c( 0, 10, 20, 50, 75, 100, 200, 250, 300, 350, 400, 450, 500, 550, 600, 700, 750, 800, 900,
             1000, 1200, 1250, 1400, 1500, 1750, 2000, 2500, 3000, 4000, 5000 )
if( bathyclines.redo ) {
  # note these polygons are created at the resolution specified in p$spatial.domain ..
  # which by default is very high ("canada.east.highres" = 0.5 km .. p$pres ).
  # For lower one specify an appropriate p$spatial.domain
  options(max.contour.segments=10000) # required if superhighres is being used
  for (g in c("canada.east.superhighres", "canada.east.highres", "canada.east", "SSE", "SSE.mpa", "snowcrab")) {
    print(g)
    pb = aegis.bathymetry::bathymetry_parameters( project.mode="stmv", spatial.domain=g )
    if( g=="snowcrab") depths = c( 10, 20, 50, 75, 100, 200, 250, 300, 350 )  # by definition .. in aegis::geo_subset
    if( g=="SSE") depths = depthsall[ depthsall < 801] # by definition
    if( g=="SSE.mpa") depths = depthsall[depthsall<2001]  # by definition
    if( grepl( "canada.east", g)) depths = depthsall
    plygn = isobath.db( p=pb, DS="isobath.redo", depths=depths  )
  }
}


### -----------------------------------------------------------------
# some test plots

pb = aegis.bathymetry::bathymetry_parameters( project.mode="stmv", spatial.domain="canada.east" ) # reset to lower resolution
depths = c( 100, 200, 300, 500, 1000)
plygn = isobath.db( p=pb, DS="isobath", depths=depths  )

coast = coastline.db( xlim=c(-75,-52), ylim=c(41,50), no.clip=TRUE )  # no.clip is an option for maptools::getRgshhsMap
plot( coast, col="transparent", border="steelblue2" , xlim=c(-68,-52), ylim=c(41,50),  xaxs="i", yaxs="i", axes=TRUE )  # ie. coastline
lines( plygn[ as.character(c( 100, 200, 300 ))], col="gray90" ) # for multiple polygons
lines( plygn[ as.character(c( 500, 1000))], col="gray80" ) # for multiple polygons
# plot( plygn, xlim=c(-68,-52), ylim=c(41,50))  # all isobaths commented as it is slow ..


# or to get in projected (planar) coords as defined by p$spatial domain
plygn = isobath.db( p=pb, DS="isobath", depths=c(100) , crs=p$internal.crs ) # as SpatialLines
plot(plygn)

plygn_aslist = coordinates( plygn)
plot( 0,0, type="n", xlim=c(-200,200), ylim=c(-200,200)  )
lapply( plygn_aslist[[1]], points, pch="." )

plygn_as_xypoints = coordinates( as( plygn, "SpatialPoints") )# ... etc...
plot(plygn_as_xypoints, pch=".",  xaxs="i", yaxs="i", axes=TRUE)