classdef VTL < handle
    %VTL A MATLAB wrapper for the VocalTractLab API
    
    properties
        libName
        samplerate_audio
        samplerate_internal
        speakerFileName
        state_samples
        state_duration
        verbose
    end
    
    methods
        function vtl = VTL(speakerFileName)
            %VTL Construct an instance of the VTL API
            vtl.speakerFileName = speakerFileName;
            [success, msg] = mkdir('VocalTractLabApi');
            if ~success
                disp(msg);
            end
            addpath('VocalTractLabApi'); % Folder containing the lib files
            if ispc
                vtl.libName = 'VocalTractLabApi';
            elseif isunix
                vtl.libName = 'libVocalTractLabApi';
            end
            vtl.state_samples = 110; % Processing rate in VTL (samples), currently 1 vocal tract state evaluation per 110 audio samples
            vtl.samplerate_audio = 44100; % Global audio sampling rate (44100 Hz default)
            vtl.samplerate_internal = vtl.samplerate_audio / vtl.state_samples; % Internal tract samplerate (ca. 400.9090... default)
            vtl.state_duration = 1 / vtl.samplerate_internal; % Processing rate in VTL (time), currently 2.49433... ms
            vtl.verbose = true; % If true, additional information is printed by some functions
            try
                vtl.initialize();
            catch ME
                if strcmp(ME.identifier, 'MATLAB:loadlibrary:FileNotFound')
                    disp(ME.message);
                    % Library not found, try to build from source
                    vtl.build();
                    vtl.initialize();
                end
            end
        end
        
        function delete(obj)
            % DELETE Destructor of the class.
            obj.close();
        end
        
        function initialize(obj)
            %INITIALIZE Initializes the VocalTractLab API library
            if ~libisloaded(obj.libName)
                if ispc
                    loadlibrary(obj.libName, obj.libName + ".h");
                elseif isunix
                    loadlibrary(obj.libName, extractAfter(obj.libName, "lib") + ".h");
                end
                disp(['Loaded library: ' obj.libName]);
            end
            
            if ~libisloaded(obj.libName)
                error(['Failed to load external library: ' obj.libName]);
            end
            
            failure = calllib(obj.libName, 'vtlInitialize', char(obj.speakerFileName));
            if (failure ~= 0)
                disp('Error in vtlInitialize()!');
                return;
            end
            
            if obj.verbose
                disp('VTL successfully initialized.');
            end
        end
        
        function close(obj)
            % CLOSE Cleans up and unloads the VocalTractLab API library
            calllib(obj.libName, 'vtlClose');
            unloadlibrary(obj.libName);
            disp(obj.libName + " unloaded.")
        end
        
        function version = get_version(obj)
            %GET_VERSION Retrieves the version of the API in terms of the
            % compile date
            
            % Init the variable version with enough characters for the version string
            % to fit in.
            version = '                                ';
            version = calllib(obj.libName, 'vtlGetVersion', version);
            if obj.verbose
                disp(['Compile date of the library: ' version]);
            end
        end
        
        function c = get_constants(obj)
            %GET_CONSTANTS Returns the used constants
            
            c = struct();
            c.audioSamplingRate = 0;
            c.n_tube_sections = 0;
            c.n_tract_params = 0;
            c.n_glottis_params = 0;
            
            [failure, c.audioSamplingRate, c.n_tube_sections, c.n_tract_params, c.n_glottis_params] = ...
                calllib(obj.libName, 'vtlGetConstants', c.audioSamplingRate, c.n_tube_sections, c.n_tract_params, c.n_glottis_params);
            if(failure)
                error("Could not retrieve constants in 'get_constants'!")
            end
        end
        
        function automatic_calculation_of_TRX_and_TRY(obj, varargin)
            %AUTOMATIC_CALCULATION_OF_TRX_AND_TRY Turns the automatic
            % calculation of the tongue root parameters TRX and TRY on or
            % off.
            
            p = inputParser;
            addOptional(p, 'automatic_calculation', true);
            parse(p, varargin{:});
            [failure] = calllib(obj.libName, 'vtlCalcTongueRootAutomatically', ...
                p.Results.automatic_calculation);
            if failure
                error('Error in vtlCalcTongueRootAutomatically()!');
            end
            
        end
        
        function p_info = get_param_info(obj, params)
            % GET_PARAM_INFO Returns information on the parameters of the
            % vocal tract or the glottis model, depending on the params.
            %
            % params: Either the string "tract" or "glottis". Controls
            % which parameters to return.
            
            if ~any(params == ["tract", "glottis"])
                disp("Unknown key in 'get_param_info'. Key must be 'tract' or 'glottis'. Returning 'tract' info now.");
                params = "tract";
            end
            if params == "tract"
                key = "n_tract_params";
                endpoint = "vtlGetTractParamInfo";
            elseif params == "glottis"
                key = "n_glottis_params";
                endpoint = "vtlGetGlottisParamInfo";
            end
            constants = obj.get_constants();
            % Reserve 32 chars for each parameter.
            names = blanks(constants.(key)*32);
            paramMin = zeros(1, constants.(key));
            paramMax = zeros(1, constants.(key));
            paramNeutral = zeros(1, constants.(key));
            
            [failure, names, paramMin, paramMax, paramNeutral] = ...
                calllib(obj.libName, endpoint, names, paramMin, ...
                paramMax, paramNeutral);
            
            if failure ~= 0
                error("Could not retrieve parameter info in 'get_param_info'!");
            end
            rowNames = split(names);
            p_info = table(paramMin', paramMax', paramNeutral', ...
                'VariableNames', {'min', 'max', 'neutral'}, ...
                'RowNames', rowNames);
            disp(p_info);
        end
        
        function param = get_tract_params_from_shape(obj, shape)
            % GET_TRACT_PARAMS_FROM_SHAPE Returns the vocal tract
            % parameters of the shape identified by SHAPE
            %
            % shape: String identifying the vocal tract shape contained in
            % the loaded speaker file.
            
            c = obj.get_constants();
            param = zeros(1, c.n_tract_params);
            
            [failure, ~, param] = ...
                calllib(obj.libName, 'vtlGetTractParams', char(shape), param);
            
            if(failure)
                error('Could not retrieve the shape parameters!')
            end
            
        end
        
        function export_tract_svg(obj, tract_params, base_file_name)
            % Exports a series of tract shapes to an SVG file
            % TRACT_PARAMS must have one row per shape
            % BASE_FILE_NAME should include the path and the prefix of the
            % filename, but not the extension.
            constants = obj.get_constants();
            if size(tract_params, 2) ~= constants.n_tract_params
                error("Number of columns does not match number of vocal tract parameters!")
            end
            for k = 1:size(tract_params, 1)
                tractParams = tract_params(k, :);
                fileName = string(base_file_name) + "_" + num2str(k) + ".svg";
                failure = ...
                    calllib(obj.libName, 'vtlExportTractSvg', tractParams, char(fileName));
                if failure ~= 0
                    error('Could not export SVG file!');
                end
            end
        end
        
        function tube_data = tract_params_to_tube_data(obj, tract_params)
            % TRACT_PARAMS_TO_TUBE_DATA Returns the tube sequence
            % corresponding to a given set of vocal tract parameters.
            %
            % tract_params: A sequence of vocal tract parameters, one row
            % per state.
            %
            % tube_data: Sequence of tube sequence data, one row per state.
            
            constants = obj.get_constants();
            if size(tract_params, 2) ~= constants.n_tract_params
                error("Number of columns does not match number of vocal tract parameters!")
            end
            tube_data = table();
            for k = 1:size(tract_params, 1)
                tractParams = tract_params(k, :);
                tubeLength_cm = zeros(1, constants.n_tube_sections);
                tubeArea_cm2 = zeros(1, constants.n_tube_sections);
                tubeArticulator = zeros(1, constants.n_tube_sections);
                incisorPos_cm = 0.0;
                tongueTipSideElevation = 0.0;
                velumOpening_cm2 = 0.0;
                [failure, tractParams, tubeLength_cm, ...
                    tubeArea_cm2, tubeArticulator, incisorPos_cm, ...
                    tongueTipSideElevation, velumOpening_cm2] = ...
                    calllib(obj.libName, 'vtlTractToTube', ...
                    tractParams, tubeLength_cm, tubeArea_cm2, ...
                    tubeArticulator, incisorPos_cm, tongueTipSideElevation, ...
                    velumOpening_cm2);
                if failure ~= 0
                    error('Something went wrong in vtlTractToTube!');
                end
                tube_data = [tube_data; {tubeLength_cm, tubeArea_cm2, ...
                    tubeArticulator, incisorPos_cm, tongueTipSideElevation, ...
                    velumOpening_cm2}];
                
            end
            tube_data.Properties.VariableNames = {'tube_length_cm', 'tube_area_cm2', ...
                'tube_articulator', 'incisor_pos_cm', 'tongue_tip_side_elevation', ...
                'velum_opening_cm2'};
        end
        
        function load_speaker_file(obj, speakerFileName)
            % LOAD_SPEAKER_FILE Loads a speaker file.
            %
            % speakerFileName: Path to the speaker file.
            
            obj.close();
            obj.speakerFileName = speakerFileName;
            obj.initialize();
        end
        
        function opts = default_transfer_function_options(obj)
            % DEFAULT_TRANSFER_FUNCTION_OPTIONS Returns the default values
            % of the paramters for the calculation of the transfer function
            % of a vocal tract shape.
            
            opts = struct('spectrumType', 0, 'radiationType', 0, 'boundaryLayer', false, ...
                'heatConduction', false, 'softWalls', false, 'hagenResistance', false, ...
                'innerLengthCorrections', false, 'lumpedElements', false, 'paranasalSinuses', false, ...
                'piriformFossa', false, 'staticPressureDrops', false);
            
            [~, opts] = ...
                calllib(obj.libName, 'vtlGetDefaultTransferFunctionOptions', opts);
        end
        
        function [tf, f] = get_transfer_function(obj, tract_params, n_spectrum_samples, opts)
            % GET_TRANSFER_FUNCTION Returns the transfer function of a
            % vocal tract shape
            %
            % TRACT_PARAMS: The vocal tract parameters of the shape of
            % interest.
            % N_SPECTRUM_SAMPLES: Number of desired samples of the transfer
            % function
            % OPTS: Options for the calculation (see
            % DEFAULT_TRANSFER_FUNCTION_OPTIONS())
            %
            % TF: Complex transfer function of the vocal tract shape
            % F: Vector of sampled frequency values
            
            mag = zeros(1, n_spectrum_samples);
            phase = zeros(1, n_spectrum_samples);
            [failed, ~, opts, mag, phase] = ...
                calllib(obj.libName, 'vtlGetTransferFunction', tract_params, ...
                n_spectrum_samples, opts, mag, phase);
            
            if (failed)
                error('Could not retrieve vocal tract transfer function!')
            end
            tf = mag .* exp(1i*phase);
            % Returned transfer function should be column vector
            tf = tf.';
            f = [0:n_spectrum_samples-1]*obj.samplerate_audio / n_spectrum_samples;
        end
        
        function synthesis_reset(obj)
            % SYNTHESIS_RESET Resets the synthesis.
            
            failure = calllib(obj.libName, 'vtlSynthesisReset');
            if failure ~= 0
                error('Something went wrong in vtlSynthesisReset!');
            end
        end
        
        function audio = synthesis_add_tube(obj, tube_data, glottis_params, n_new_samples)
            numNewSamples = n_new_samples;
            audio = zeros(1, numNewSamples);
            if size(tube_data,1 ) > 1
                warning('More than one rows of tube data passed. I will only use the first state/row!');
            end
            tubeLength_cm = tube_data.tube_length_cm(1,:);
            tubeArea_cm2 = tube_data.tube_area_cm2(1, :);
            tubeArticulator = tube_data.tube_articulator(1,:);
            incisorPos_cm = tube_data.incisor_pos_cm(1);
            velumOpening_cm = tube_data.velum_opening_cm(1);
            tongueTipSideElevation = tube_data.tongue_tip_side_elevation(1);
            newGlottisParams = glottis_params;
            [failure, audio, tubeLength_cm, tubeArea_cm2, tubeArticulator, ...
                newGlottisParams] = ...
                calllib(obj.libName, 'vtlSynthesisAddTube', ...
                numNewSamples, audio, tubeLength_cm, tubeArea_cm2, ...
                tubeArticulator, incisorPos_cm, velumOpening_cm, ...
                tongueTipSideElevation, newGlottisParams);
            if failure ~= 0
                error('Something went wrong in vtlSynthesisAddTube!');
            end
        end
        
        function audio = synthesis_add_state(obj, tract_state, glottis_state, n_new_samples)
            numNewSamples = n_new_samples;
            audio = zeros(1, numNewSamples);
            tractParams = tract_state;
            glottisParams = glottis_state;
            [failure, audio, tractParams, glottisParams] = ...
                calllib(obj.libName, 'vtlSynthesisAddTract', ...
                numNewSamples, audio, tractParams, glottisParams);
            if failure ~= 0
                error('Something went wrong in vtlSynthesisAddTract!');
            end
        end
        
        function audio = synth_block(obj, tract_params, glottis_params, varargin)
            p = inputParser;
            addOptional(p, 'verbose', true);
            addOptional(p, 'state_samples', obj.state_samples);
            parse(p, varargin{:});
            constants = obj.get_constants();
            if size(tract_params, 2) ~= constants.n_tract_params
                error("Number of columns does not match number of vocal tract parameters!")
            end
            if size(glottis_params, 2) ~= constants.n_glottis_params
                error("Number of columns does not match number of glottis parameters!")
            end
            if size(tract_params, 1) ~= size(glottis_params, 1)
                disp( 'TODO: Warning: Length of tract_params and glottis_params do not match. Will modify glottis_params to match.')
                % Todo: Match length
            end
            numFrames = size(tract_params, 1);
            tractParams = reshape(tract_params.', 1, []);
            glottisParams = reshape(glottis_params.', 1, []);
            frameStep_samples = p.Results.state_samples;
            audio = zeros(1, numFrames * frameStep_samples);
            enableConsoleOutput = p.Results.verbose;
            [failure, ~, ~, audio] = calllib(obj.libName, 'vtlSynthBlock', tractParams, ...
                glottisParams, numFrames, frameStep_samples, audio, ...
                enableConsoleOutput);
            if failure ~= 0
                error("Error in 'synth_block'!");
            end
        end
        
        function segment_sequence_to_gestural_score(obj, segFileName, gesFileName)
            [failure, segFileName, gesFileName] = calllib(obj.libName, ...
                'vtlSegmentSequenceToGesturalScore', segFileName, gesFileName);
            if failure ~= 0
                error('Something went wrong in vtlSegmentSequenceToGesturalScore!');
            end
            if obj.verbose
                disp("Created gestural score from file: " + string(segFileName));
            end
        end
        
        function duration = get_gestural_score_audio_duration(obj, ges_file_path, return_samples)
            gesFileName = ges_file_path;
            numAudioSamples = 0;
            numGestureSamples = 0;
            [failure, gesFileName, numAudioSamples, numGestureSamples] = ...
                calllib(obj.libName, 'vtlGetGesturalScoreDuration', ...
                gesFileName, numAudioSamples, numGestureSamples);
            if failure ~= 0
                error('Something went wrong in vtlGetGesturalScoreDuration!');
            end
            if return_samples  % Return the number of samples in audio file
                duration = numAudioSamples;
            else  % Return the duration in seconds
                duration = numAudioSamples / obj.samplerate_audio;
            end
        end
        
        function varargout = gestural_score_to_audio(obj, ges_file_path, varargin)
            p = inputParser;
            addOptional(p, 'audio_file_path', '');
            addOptional(p, 'return_audio', true);
            addOptional(p, 'return_n_samples', false);
            parse(p, varargin{:});
            if strcmp(p.Results.audio_file_path, '') && p.Results.return_audio == false
                warning('Function returns nothing. Either pass an output audio file path or set return_audio to true!');
            end
            wavFileName = p.Results.audio_file_path;
            gesFileName = ges_file_path;
            if p.Results.return_audio
                audio = zeros(1, obj.get_gestural_score_audio_duration(ges_file_path, true));
            else
                audio = libpointer(double);  % NULL pointer
            end
            if obj.verbose
                enableConsoleOutput = 1;
            else
                enableConsoleOutput = 0;
            end
            numSamples = 0;
            [failure, gesFileName, wavFileName, audio, numSamples] = ...
                calllib(obj.libName, 'vtlGesturalScoreToAudio', ...
                gesFileName, wavFileName, audio, numSamples, ...
                enableConsoleOutput);
            if failure ~= 0
                error('Something went wrong in vtlGesturalScoreToAudio!');
            end
            if p.Results.return_audio
                varargout{1} = audio;
            end
        end
        
        function varargout = gestural_score_to_tract_sequence(obj, ges_file_path, varargin)
            p = inputParser;
            addOptional(p, 'tract_file_path', '');
            addOptional(p, 'return_Sequence', false);
            parse(p, varargin{:});
            gesFileName = ges_file_path;
            if strcmp(p.Results.tract_file_path, '')
                [path, name, ~] = fileparts(gesFileName);
                tract_file_path = fullfile(path, strcat(name, '_tractSeq.txt'));
            else
                tract_file_path = p.Results.tract_file_path;
            end
            tractSequenceFileName = tract_file_path;
            
            [failure, gesFileName, tractSequenceFileName] = calllib(obj.libName, ...
                'vtlGesturalScoreToTractSequence', gesFileName, tractSequenceFileName);
            if failure
                error('Error in vtlGesturalScoreToTractSequence()!');
            end
            if obj.verbose
                fprintf('Created TractSeq of file: %s\n', gesFileName);
            end
            if p.Results.return_Sequence && nargout > 1
                varargout = cell(1,nargout);
                [varargout{1}, varargout{2}] = obj.tract_seq_to_table(tractSequenceFileName);
            end
        end
        
        function varargout = tract_sequence_to_audio(obj, tract_seq_path, varargin)
            p = inputParser;
            addOptional(p, 'audio_file_path', '');
            addOptional(p, 'return_audio', true);
            addOptional(p, 'return_n_samples', false);
            parse(p, varargin{:});
            if strcmp(p.Results.audio_file_path, '') && ~p.Results.return_audio
                fprintf('Warning! Function cannot return anything!');
            end
            wavFileName = p.Results.audio_file_path;
            tractSequenceFileName = tract_seq_path;
            if p.Results.return_audio
                audio = zeros(1, obj.get_tract_seq_len(tract_seq_path) * ...
                    ceil(obj.state_duration * obj.samplerate_audio));
            else
                audio = libpointer(double);  % NULL pointer
            end
            numSamples = 0;
            [failure, tractSequenceFileName, wavFileName, audio, numSamples] ...
                = calllib(obj.libName, 'vtlTractSequenceToAudio', ...
                tractSequenceFileName, wavFileName, audio, numSamples);
            if obj.verbose
                fprintf('Audio generated: %s\n', tract_seq_path);
            end
            if p.Results.return_audio
                varargout{1} = audio;
            end
        end
        
        function tract_seq_len = get_tract_seq_len(~, tract_seq_path)
            fid = fopen(tract_seq_path);
            for i = 1:8
                line = fgetl(fid);
            end
            tract_seq_len = str2num(line);
        end
        
        function limited_tract_state = tract_state_to_limited_tract_state(obj, tract_params)
            constants = obj.get_constants();
            limited_tract_state = [];
            for k = 1:size(tract_params, 1)
                inTractParams = tract_params(k, :);
                outTractParams = zeros(1, constants.n_tract_params);
                [outTractParams] = calllib(obj.libName, 'vtlInputTractToLimitedTract', ...
                    intractParams, outTractParams);
                limited_tract_state = [tract_param_data; outTractParams];
            end
        end
        
        function save_transfer_function(~, fileName, tf, f)
            if length(tf) ~= length(f)
                error('Mismatch of length of transfer function and frequency vector!');
            end
            fileID = fopen(fileName,'w');
            fprintf(fileID, '%s %d\n', 'num_points:', length(tf));
            fprintf(fileID, '%s  %s  %s\n', 'frequency_Hz', 'magnitude', 'phase_rad');
            for i = 1:length(f)
                fprintf(fileID, '%f  %f  %f\n', f(i), abs(tf(i)), angle(tf(i)));
            end
            fclose(fileID);
        end
        
        function [TG, TVT] = tract_seq_to_table(~, tract_file_path)
            opts = detectImportOptions(tract_file_path, 'NumHeaderLines', 8);
            T = readtable(tract_file_path, opts);
            TG = T(1:2:end, :);
            TVT = T(2:2:end, :);
            TG = rmmissing(TG, 2);
            TVT = rmmissing(TVT, 2);
        end
    end
    methods (Access = private)
        function status = build(obj)
            fprintf("Trying to build using CMake...\n");
            try
                obj.build_with_CMake();
                success = true;
            catch ME
                if strcmp(ME.identifier, 'BuildProcess:CMakeNotFound') || strcmp(ME.identifier, 'BuildProcess:CMakeError')
                    success = false;
                else
                    disp(ME.identifier);
                end
            end
            if ~success
                try
                    if ispc
                        % Build the Visual Studio project using MSBuild.exe
                        fprintf("Trying to build using MSBuild...\n");
                        obj.build_with_MSBuild();
                        success = true;
                    end
                catch ME
                    if strcmp(ME.identifier, 'BuildProcess:MSBuildNotFound') || strcmp(ME.identifier, 'BuildProcess:MSBuildError')
                        success = false;
                    else
                        disp(ME.identifier);
                    end
                end
                if ~success
                    throw(MException('BuildProcess:Failure', 'Could not build VocalTractLab API library.'));
                end
            end
        end
        
        function build_with_CMake(obj)
            [noCMake, out] = system('cmake --version');
            if noCMake
                throw(MException('BuildProcess:CMakeNotFound', ...
                    'Could not find CMake'));
            end
            [error, msg] = mkdir('build');
            cd build;
            [error, out] = system('cmake ../VocalTractLabBackend-dev -DCMAKE_BUILD_TYPE=Release', '-echo');
            if error
                throw(MException('BuildProcess:CMakeError', ...
                    out));
            else
                fprintf("Build tree successfully generated.'\n");
            end
            numThreads = maxNumCompThreads;
            [error, out] = system(['cmake --build . -j', num2str(numThreads)], '-echo');
            cd ..;
            if error
                throw(MException('BuildProcess:CMakeError', ...
                    out));
            else
                fprintf("Build successful. Moving library files to folder 'VocalTractLabApi'\n");
            end
            [success, msg] = movefile('build/libVocalTractLabApi.so', 'VocalTractLabApi/');
            if ~success
                throw(MException('BuildProcess:FileError', ...
                    msg));
            end
            [success, msg] = copyfile('VocalTractLabBackend-dev/VocalTractLabApi.h', 'VocalTractLabApi/');
            if ~success
                throw(MException('BuildProcess:FileError', ...
                    msg));
            end
        end
        
        function build_with_MSBuild(obj)
            [status, out] = system('"build/MSBuild.bat" VocalTractLabBackend-dev/VocalTractLabApi.vcxproj /p:configuration=Release /p:Platform=x64', '-echo');
            if status == 0
                fprintf("Build successful. Moving library files to folder 'VocalTractLabApi'\n");
                [success, msg] = movefile('VocalTractLabBackend-dev\x64\Release\VocalTractLabApi.dll', ...
                    'VocalTractLabApi\');
                if ~success
                    disp(msg);
                end
                [success, msg] = movefile('VocalTractLabBackend-dev\x64\Release\VocalTractLabApi.lib', ...
                    'VocalTractLabApi\');
                if ~success
                    disp(msg);
                end
                [success, msg] = copyfile('VocalTractLabBackend-dev\VocalTractLabApi.h', ...
                    'VocalTractLabApi\');
                if ~success
                    disp(msg);
                end
                fprintf("Cleaning up...\n");
                rmdir('VocalTractLabBackend-dev\x64', 's');
                fprintf("Done.\n");
                
                status = success;
            end
        end
    end
end

