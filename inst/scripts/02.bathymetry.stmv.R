
# Bathymetry


# Spatial interpolation using stmv
# Total "superhighres": 2-5 GB/process and 4 GB in parent for fft
# gam method requires more ~ 2X
# boundary def takes too long .. too much data to process -- skip
# "highres": ~ 20 hr with 8, 3.2 Ghz cpus on thoth using fft method jc: 2016 or 2~ 6 hr on hyperion
# "superhighres" fft: looks to be the best in performance/quality; req ~5 GB per process req
# FFT is the method of choice for speed and ability to capture the variability
# krige method is a bit too oversmoothed, especially where rapid changes are occuring


#  ~40 hrs
scale_ram_required_main_process = 20 # GB twostep / fft
scale_ram_required_per_process  = 6 # twostep / fft /fields vario ..  (mostly 0.5 GB, but up to 5 GB)
scale_ncpus = min( parallel::detectCores(), floor( (ram_local()- scale_ram_required_main_process) / scale_ram_required_per_process ) )

# ~96 hrs
interpolate_ram_required_main_process = 10 # GB twostep / fft
interpolate_ram_required_per_process  = 8 # twostep / fft /fields vario ..
interpolate_ncpus = min( parallel::detectCores(), floor( (ram_local()- interpolate_ram_required_main_process) / interpolate_ram_required_per_process ) )

pres =0.2
p = aegis.bathymetry::bathymetry_parameters(
  project_class="stmv",
  data_root = project.datadirectory( "aegis", "bathymetry" ),
  DATA = 'bathymetry.db( p=p, DS="stmv_inputs" )',
  stmv_variables = list(Y="z"),  # required as fft has no formulae
  inputdata_spatial_discretization_planar_km = 0.2,  # 0.2==p$pres; .. 10x10 = 100 data point in each grid controls resolution of data prior to modelling (km .. ie 20 linear units smaller than the final discretization pres)
  spatial_domain = "canada.east.superhighres",
  spatial_domain_subareas = c( "canada.east.highres", "canada.east",  "SSE", "SSE.mpa" , "snowcrab"),
  aegis_dimensionality="space",
  stmv_global_modelengine = "none",  # only marginally useful .. consider removing it and use "none",
  stmv_local_modelengine="fft",
  stmv_fft_filter = "matern tapered lowpass modelled fast_predictions", #  act as a low pass filter first before matern with taper .. depth has enough data for this. Otherwise, use:
  stmv_lowpass_nu = 0.5, # exp
  stmv_lowpass_phi = stmv::matern_distance2phi( distance=0.2, nu=0.5, cor=0.1 ),  # note: p$pres = 0.2
  stmv_autocorrelation_fft_taper = 0.9,  # benchmark from which to taper
  stmv_autocorrelation_localrange = 0.1,  # for output to stats
  stmv_autocorrelation_basis_interpolation = c(0.25, 0.1, 0.05, 0.01),
  stmv_variogram_method = "fft",
  stmv_filter_depth_m = FALSE,  # need data above sea level to get coastline
  stmv_Y_transform =list(
    transf = function(x) {log10(x + 2500)} ,
    invers = function(x) {10^(x) - 2500}
  ), # data range is from -1667 to 5467 m: make all positive valued
  stmv_rsquared_threshold = 0.01, # lower threshold  .. ignore
  stmv_distance_statsgrid = 5, # resolution (km) of data aggregation (i.e. generation of the ** statistics ** )
  stmv_distance_prediction_limits =c( 3, 25 ), # range of permissible predictions km (i.e 1/2 stats grid to upper limit based upon data density)
  stmv_distance_scale = c( 5, 10, 20, 25, 40, 80, 150, 200), # km ... approx guesses of 95% AC range
  stmv_distance_basis_interpolation = c(  2.5 , 5, 10, 15, 20, 40, 80, 150, 200 ) , # range of permissible predictions km (i.e 1/2 stats grid to upper limit) .. in this case 5, 10, 20
  stmv_nmin = 90, # min number of data points req before attempting to model in a localized space
  stmv_nmax = 900, # no real upper bound.. just speed /RAM
  stmv_force_complete_method = "linear_interp",
  stmv_runmode = list(
    # scale = rep("localhost", scale_ncpus),
    interpolate = list(
      c1 = rep("localhost", interpolate_ncpus),  # ncpus for each runmode
      c2 = rep("localhost", interpolate_ncpus),  # ncpus for each runmode
      c3 = rep("localhost", max(1, interpolate_ncpus-1)),
      c4 = rep("localhost", max(1, interpolate_ncpus-1)),
      c5 = rep("localhost", max(1, interpolate_ncpus-2))
    ),
    # if a good idea of autocorrelation is missing, forcing via explicit distance limits is an option
    # interpolate_distance_basis = list(
    #   d1 = rep("localhost", interpolate_ncpus),
    #   d2 = rep("localhost", interpolate_ncpus),
    #   d3 = rep("localhost", max(1, interpolate_ncpus-1)),
    #   d4 = rep("localhost", max(1, interpolate_ncpus-1)),
    #   d5 = rep("localhost", max(1, interpolate_ncpus-2)),
    #   d6 = rep("localhost", max(1, interpolate_ncpus-2))
    # ),
    interpolate_predictions = list(
      c1 = rep("localhost", max(1, interpolate_ncpus-1)),  # ncpus for each runmode
      c2 = rep("localhost", max(1, interpolate_ncpus-1)),  # ncpus for each runmode
      c3 = rep("localhost", max(1, interpolate_ncpus-2)),
      c4 = rep("localhost", max(1, interpolate_ncpus-3)),
      c5 = rep("localhost", max(1, interpolate_ncpus-4)),
      c6 = rep("localhost", max(1, interpolate_ncpus-4)),
      c7 = rep("localhost", max(1, interpolate_ncpus-5))
     ),
    globalmodel = FALSE,
    # restart_load = "interpolate_correlation_basis_0.01" ,  # only needed if this is restarting from some saved instance
    save_intermediate_results = TRUE,
    save_completed_data = TRUE

  )  # ncpus for each runmode
)



if (0) {  # model testing
  # if resetting data for input to stmv run this or if altering discretization resolution
  bathymetry.db( p=p, DS="stmv_inputs_redo" )  # recreate fields for .. requires 60GB+
  # p$restart_load = paste("interpolate_correlation_basis_", p$stmv_autocorrelation_basis_interpolation[length(p$stmv_autocorrelation_basis_interpolation)], sep="")  # to choose the last save
}

stmv( p=p )  # This will take from 40-70 hrs, depending upon system


# quick view
  predictions = stmv_db( p=p, DS="stmv.prediction", ret="mean" )
  statistics  = stmv_db( p=p, DS="stmv.stats" )
  locations   = spatial_grid( p )

  # comparisons
  dev.new(); surface( as.image( Z=predictions, x=locations, nx=p$nplons, ny=p$nplats, na.rm=TRUE) )

  # stats
  # p$statsvars = c( "sdTotal", "rsquared", "ndata", "sdSpatial", "sdObs", "phi", "nu", "localrange" )
  dev.new(); levelplot( predictions ~ locations[,1] + locations[,2], aspect="iso" )

  dev.new(); levelplot( statistics[,match("nu", p$statsvars)]  ~ locations[,1] + locations[,2], aspect="iso" ) # nu
  dev.new(); levelplot( statistics[,match("sdSpatial", p$statsvars)]  ~ locations[,1] + locations[,2], aspect="iso" ) #sd total
  dev.new(); levelplot( statistics[,match("localrange", p$statsvars)]  ~ locations[,1] + locations[,2], aspect="iso" ) #localrange

# water only
o = which( predictions>0 & predictions <1000)
#levelplot( log( statistics[o,match("sdTotal", p$statsvars)] ) ~ locations[o,1] + locations[o,2], aspect="iso" ) #sd total
levelplot( log(predictions[o]) ~ locations[o,1] + locations[o,2], aspect="iso" )



# bring together stats and predictions and any other required computations: slope and curvature
# and then regrid/warp as the interpolation process is so expensive, regrid/upscale/downscale based off the above run
# .. still uses about 30-40 GB as the base layer is "superhighres" ..
# if parallelizing .. use different servers than local nodes
bathymetry.db( p=p, DS="complete.redo" ) # finalise at diff resolutions 15 min ..
bathymetry.db( p=p, DS="baseline.redo" )  # coords of areas of interest ..filtering of areas and or depth to reduce file size, in planar coords only



### -----------------------------------------------------------------
# to update/recreate new polygons, run the following:
bathyclines.redo = FALSE
# bathyclines.redo = TRUE
depthsall = c( 0, 10, 20, 50, 75, 100, 200, 250, 300, 350, 400, 450, 500, 550, 600, 700, 750, 800, 900,
             1000, 1200, 1250, 1400, 1500, 1750, 2000, 2500, 3000, 4000, 5000 )
if( bathyclines.redo ) {
  # note these polygons are created at the resolution specified in p$spatial_domain ..
  # which by default is very high ("canada.east.highres" = 0.5 km .. p$pres ).
  # For lower one specify an appropriate p$spatial_domain
  # options(max.contour.segments=1000) # might be required if superhighres is being used
  for (g in c("canada.east.superhighres", "canada.east.highres", "canada.east", "SSE", "SSE.mpa", "snowcrab")) {
    print(g)
    pb = aegis.bathymetry::bathymetry_parameters( project_class="stmv", spatial_domain=g )
    if( g=="snowcrab") depths = c( 10, 20, 50, 75, 100, 200, 250, 300, 350 )  # by definition .. in geo_subset
    if( g=="SSE") depths = depthsall[ depthsall < 801] # by definition
    if( g=="SSE.mpa") depths = depthsall[depthsall<2001]  # by definition
    if( grepl( "canada.east", g)) depths = depthsall
    plygn = isobath.db( p=pb, DS="isobath.redo", depths=depths  )
  }
}


if (0) {
    ### -----------------------------------------------------------------
    # some test plots
    RLibrary( "aegis.bathymetry" , "aegis.coastline", "aegis.polygons")

    pb = aegis.bathymetry::bathymetry_parameters( project_class="stmv", spatial_domain="canada.east" ) # reset to lower resolution
    depths = c( 100, 200, 300, 500, 1000)
    plygn = isobath.db( p=pb, DS="isobath", depths=depths  )

    coast = coastline.db( xlim=c(-75,-52), ylim=c(41,50), no.clip=TRUE )  # no.clip is an option for maptools::getRgshhsMap
    plot( coast, col="transparent", border="steelblue2" , xlim=c(-68,-52), ylim=c(41,50),  xaxs="i", yaxs="i", axes=TRUE )  # ie. coastline
    lines( plygn[ as.character(c( 100, 200, 300 ))], col="gray90" ) # for multiple polygons
    lines( plygn[ as.character(c( 500, 1000))], col="gray80" ) # for multiple polygons
    # plot( plygn, xlim=c(-68,-52), ylim=c(41,50))  # all isobaths commented as it is slow ..


    # or to get in projected (planar) coords as defined by p$spatial_domain
    plygn = isobath.db( p=pb, DS="isobath", depths=c(100) , crs=pb$aegis_proj4string_planar_km ) # as SpatialLines
    plot(plygn)

    plygn_aslist = coordinates( plygn)
    plot( 0,0, type="n", xlim=c(-200,200), ylim=c(-200,200)  )
    lapply( plygn_aslist[[1]], points, pch="." )

    plygn_as_xypoints = coordinates( as( plygn, "SpatialPoints") )# ... etc...
    plot(plygn_as_xypoints, pch=".",  xaxs="i", yaxs="i", axes=TRUE)
}



# a few plots :
pb = aegis.bathymetry::bathymetry_parameters( project_class="stmv", spatial_domain="canada.east.highres" )
bathymetry.figures( p=pb, varnames=c("z", "dZ", "ddZ", "b.localrange"), logyvar=TRUE, savetofile="png" )
bathymetry.figures( p=pb, varnames=c("b.sdTotal", "b.sdSpatial", "b.sdObs"), logyvar=FALSE, savetofile="png" )

pb = aegis.bathymetry::bathymetry_parameters( project_class="stmv", spatial_domain="canada.east.superhighres" )
bathymetry.figures( p=pb, varnames=c("z", "dZ", "ddZ", "b.localrange"), logyvar=TRUE, savetofile="png" )
bathymetry.figures( p=pb, varnames=c("b.sdTotal", "b.sdSpatial", "b.sdObs"), logyvar=FALSE, savetofile="png" )


pb = aegis.bathymetry::bathymetry_parameters( project_class="stmv", spatial_domain="snowcrab" )
bathymetry.figures( p=pb, varnames=c("z", "dZ", "ddZ", "b.localrange"), logyvar=TRUE, savetofile="png" )
bathymetry.figures( p=pb, varnames=c("b.sdTotal", "b.sdSpatial", "b.sdObs"), logyvar=FALSE, savetofile="png" )


pb = aegis.bathymetry::bathymetry_parameters( project_class="stmv", spatial_domain="SSE" )
bathymetry.figures( p=pb, varnames=c("z", "dZ", "ddZ", "b.localrange"), logyvar=TRUE, savetofile="png" )
bathymetry.figures( p=pb, varnames=c("b.sdTotal", "b.sdSpatial", "b.sdObs"), logyvar=FALSE, savetofile="png" )



