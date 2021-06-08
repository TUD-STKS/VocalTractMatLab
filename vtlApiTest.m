%% Testing the MATLAB wrapper for the VTL API
clearvars;
%% Get transfer function
vtl = VTL('VocalTractLabBackend-dev/Unit Tests/JD2.speaker');
opts = vtl.default_transfer_function_options();
opts.spectrumType = 'SPECTRUM_PU';
opts.radiationType = 'PISTONINWALL_RADIATION';
opts.paranasalSinuses = false;
opts.piriformFossa = false;
opts.staticPressureDrops = false;
opts.lumpedElements = false;
opts.innerLengthCorrections = false;
opts.boundaryLayer = true;
opts.heatConduction = true;
opts.softWalls = true;
opts.hagenResistance = false;

[pu,f] = vtl.get_transfer_function(vtl.get_tract_params_from_shape('a'), 4096, opts);
plot(f, abs(pu))
xlabel('Frequency [Hz]');
ylabel('Magnitude');

