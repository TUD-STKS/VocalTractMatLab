%% Testing the MATLAB wrapper for the VTL API
clearvars;
%% Get transfer function
addpath('..')
vtl = VTL('../../speaker-files/female.speaker');
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

[pu,f] = vtl.get_transfer_function(vtl.get_tract_params_from_shape('a_no-pf_mm-formants'), 4096, opts);
plot(f, abs(pu))

%% Low-pass filter transfer function in the frequency domain 
% to get rid of ringing from boxcar window
load('lp-fc_10kHz-fs_44p1kHz.mat');
h_lp =  freqz(H_lp, 4096, 'whole');
pu_filtered = pu .* h_lp;
subplot(2,1,1)
f = linspace(0, 44100, 4096);
plot(f, abs(pu), '--'); hold on;
plot(f, abs(pu_filtered)); hold off;
xlabel('Frequency [Hz]')
subplot(2,1,2)
ir = tf2ir(pu_filtered);
plot(ir);
xlabel('Sample $k$')



