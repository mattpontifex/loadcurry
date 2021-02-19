function [EEG, command] = loadcurry(fullfilename, varargin)
%   Import a Neuroscan Curry file into EEGLAB. Currently supports Curry version 6, 7, 8,
%   and 9 data files (both continuous and epoched). Epoched
%   datasets are loaded in as continuous files with boundary events. Data
%   can be re-epoched using EEGLAB/ERPLAB functions.
%
%   Input Parameters:
%        1    Specify the filename of the Curry file (extension should be either .cdt, .dap, .dat, or .rs3). 
%
%   Example Code:
%
%       >> EEG = pop_loadcurry;   % an interactive uigetfile window
%       >> EEG = loadcurry;   % an interactive uigetfile window
%       >> EEG = loadcurry('C:\Studies\File1.cdt');    % no pop-up window 
%
%   Optional Parameters:
%       1     'CurryLocations' - Boolean parameter to determine if the sensor
%               locations are carried forward from Curry [1, 'True'] or if the channel
%               locations from EEGLAB should be used [0, 'False' Default].
%       2     'KeepTriggerChannel' - Boolean parameter to determine if the trigger channel is retained in the array [1, 'True' Default] or if the trigger channel
%               should be removed [0, 'False']. I debated adjusting this parameter but given the EEGLAB/ERPLAB
%               bugs associated with trigger events, this provides a nice
%               data check. You can always delete the channel or relocate
%               it later.
%
%   Author for reading into Matlab: Neuroscan 
%   Author for translating to EEGLAB: Matthew B. Pontifex, Health Behaviors and Cognition Laboratory, Michigan State University, February 17, 2021
%   Github: https://github.com/mattpontifex/loadcurry
%
%   revision 3.1 - Integrate labels for epoched events.
%
%   revision 3.0 - Curry9 compatibility.
%
%   revision 2.1 - 
%     Updated to make sure event latencies are in double format.
%
%   revision 2.0 - 
%     Updated for Curry8 compatibility and compatibility with epoched
%     datasets. Note that Curry only carries forward trigger events used in
%     the epoching process.
%
%   revision 1.3 -
%     Revised to be backward compatible through r2010a - older versions may work but have not been tested.
%
%   revision 1.2 -
%     Fixed an issue related to validating the trigger markers.
%
%   revision 1.1 - 
%     Fixed a problem with reading files in older versions of matlab.
%     Added import of impedance check information for the most recent check
%        as well as the median of the last 10 checks. Data is available in
%        EEG.chanlocs
%     Moved function to loadcurry() and setup pop_loadcurry() as the pop up shell. 
%     Created catch for user cancelling file selection dialog. Now throws
%        an error to not overwrite what is in the EEG variable
%
%   If there is an error with this code, please email pontifex@msu.edu with the issue and I'll see what I can do.


    command = '';
    if nargin < 1 % No file was identified in the call
        try
            % flip to pop_loadcurry()
            [EEG, command] = pop_loadcurry();
        catch
            % only error that should occur is user cancelling prompt
            error('loadcurry(): File selection cancelled. Error thrown to avoid overwriting data in EEG.')
        end
    else
        
        if ~isempty(varargin)
             r=struct(varargin{:});
        end
        try, r.CurryLocations; catch, r.CurryLocations = 'False'; end
        try, r.KeepTriggerChannel; catch, r.KeepTriggerChannel = 'True'; end
        if strcmpi(r.CurryLocations, 'True') | (r.CurryLocations == 1)
            r.CurryLocations = 'True';
        else
            r.CurryLocations = 'False';
        end
        if strcmpi(r.KeepTriggerChannel, 'True') | (r.KeepTriggerChannel == 1)
            r.KeepTriggerChannel = 'True';
        else
            r.KeepTriggerChannel = 'False';
        end
       
        
        
        EEG = [];
        EEG = eeg_emptyset;
        [pathstr,name,ext] = fileparts(fullfilename);
        filename = [name,ext];
        filepath = [pathstr, filesep];
        file = [pathstr, filesep, name];

        % Ensure the appropriate file types exist under that name
        boolfiles = 1;
        curryvers = 0;
        if strcmpi(ext, '.cdt')
            curryvers = 9;
            if (exist([file '.cdt'], 'file') == 0) || ((exist([file '.cdt.dpa'], 'file') == 0) && (exist([file '.cdt.dpo'], 'file') == 0))
                boolfiles = 0;
                
                if (exist([file '.cdt'], 'file') == 0)
                    error('Error in pop_loadcurry(): The requested filename "%s" in "%s" does not have a .cdt file created by Curry 8 and 9.', name, filepath)
                end
                if ((exist([file '.cdt.dpa'], 'file') == 0) && (exist([file '.cdt.dpo'], 'file') == 0))
                    error('Error in pop_loadcurry(): The requested filename "%s" in "%s" does not have a .cdt.dpa/o file created by Curry 8 and 9.', name, filepath)
                end
            end
        else
            curryvers = 7;
            if (exist([file '.dap'], 'file') == 0) || (exist([file '.dat'], 'file') == 0) || (exist([file '.rs3'], 'file') == 0)
                boolfiles = 0;
                error('Error in pop_loadcurry(): The requested filename "%s" in "%s" does not have all three file components (.dap, .dat, .rs3) created by Curry 6 and 7.', name, filepath)
            end
        end

        if (boolfiles == 1)

            %% Provided by Neuroscan enclosed within Program Files Folder for Curry7 (likely to be included in Curry8/9)
            % Received updated version on 2-5-2021 from Michael Wagner, Ph.D., Senior Scientist, Compumedics Germany GmbH, Heu�weg 25, 20255 Hamburg, Germany
            % Modified to retain compatibility with earlier versions of Matlab and Older Computers by Pontifex
            
            if (curryvers == 7)
                datafileextension = '.dap';
            elseif (curryvers > 7)
                datafileextension = '.cdt.dpa';
                if (exist([file '.cdt.dpo'], 'file') > 0)
                    datafileextension = '.cdt.dpo';
                end
            end
            
            % Open parameter file
            fid = fopen([file, datafileextension],'rt');
            if (fid == -1)
               error('Error in loadcurry(): Unable to open file.') 
            end
            
            try
                cell = textscan(fid,'%s','whitespace','','endofline','�');
            catch
                % In case of earlier versions of Matlab or Older Computers
                fclose(fid); 
                fid = fopen([file, datafileextension],'rt');
                f = dir([file, datafileextension]);
                try
                    cell = textscan(fid,'%s','whitespace','','endofline','�','BufSize',round(f.bytes+(f.bytes*0.2)));
                catch
                    fclose(fid); 
                    fid = fopen([file, datafileextension],'rt');
                    cell = textscan(fid,'%s','whitespace','','BufSize',round(f.bytes+(f.bytes*0.2)));
                end
            end
            fclose(fid);            
            cont = cell2mat(cell{1});

            % read parameters from file
            % tokens (second line is for Curry 6 notation)
            tok = { 'NumSamples'; 'NumChannels'; 'NumTrials'; 'SampleFreqHz';  'TriggerOffsetUsec';  'DataFormat'; 'DataSampOrder';   'SampleTimeUsec'; 
                    'NUM_SAMPLES';'NUM_CHANNELS';'NUM_TRIALS';'SAMPLE_FREQ_HZ';'TRIGGER_OFFSET_USEC';'DATA_FORMAT';'DATA_SAMP_ORDER'; 'SAMPLE_TIME_USEC' };

            % scan in cell 1 for keywords - all keywords must exist!
            nt = size(tok,1);
            a = zeros(nt,1);
            for i = 1:nt
                 ctok = tok{i,1};
                 ix = strfind(cont,ctok);
                 if ~isempty ( ix )
                     text = sscanf(cont(ix+numel(ctok):end),' = %s');     % skip =
                     if strcmp ( text,'ASCII' ) || strcmp ( text,'CHAN' ) % test for alphanumeric values
                         a(i) = 1;
                     else 
                         c = sscanf(text,'%f');         % try to read a number
                         if ~isempty ( c )
                             a(i) = c;                  % assign if it was a number
                         end
                     end
                 end 
            end

            % derived variables. numbers (1) (2) etc are the token numbers
            nSamples    = a(1)+a(1+nt/2);
            nChannels   = a(2)+a(2+nt/2);
            nTrials     = a(3)+a(3+nt/2);
            fFrequency  = a(4)+a(4+nt/2);
            fOffsetUsec = a(5)+a(5+nt/2);
            nASCII      = a(6)+a(6+nt/2);
            nMultiplex  = a(7)+a(7+nt/2);
            fSampleTime = a(8)+a(8+nt/2);

            if ( fFrequency == 0 && fSampleTime ~= 0 )
                fFrequency = 1000000 / fSampleTime;
            end   
            
            %Search for Impedance Values
            tixstar = strfind(cont,'IMPEDANCE_VALUES START_LIST');
            tixstop = strfind(cont,'IMPEDANCE_VALUES END_LIST');

            impedancelist = []; 
            impedancematrix = [];

            if (~isempty(tixstar)) && (~isempty(tixstop))
                text = cont(tixstar:tixstop-1);
                tcell = textscan(text,'%s');
                tcell = tcell{1,1};
                for tcC = 1:size(tcell,1)
                   tcell{tcC} = str2num(tcell{tcC}); % data was read in as strings - force to numbers
                   if ~isempty(tcell{tcC}) % skip if it is not a number
                       impedancelist(end+1) = tcell{tcC};
                   end
                end

                % Curry records last 10 impedances
                impedancematrix = reshape(impedancelist,[(size(impedancelist,2)/10),10])';
                impedancematrix(impedancematrix == -1) = NaN; % screen for missing
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % open file containing labels
            if (curryvers == 7)
                datafileextension = '.rs3';
            elseif (curryvers > 7)
                datafileextension = '.cdt.dpa';
                if (exist([file '.cdt.dpo'], 'file') > 0)
                    datafileextension = '.cdt.dpo';
                end
            end
            
            fid = fopen([file, datafileextension],'rt');
            if (fid == -1)
               error('Error in loadcurry(): Unable to open file.') 
            end
            try
                cell = textscan(fid,'%s','whitespace','','endofline','�');
            catch
                fclose(fid);
                fid = fopen([file, datafileextension],'rt');
                f = dir([file, datafileextension]);
                try
                    cell = textscan(fid,'%s','whitespace','','endofline','�','BufSize',round(f.bytes+(f.bytes*0.2)));
                catch
                    fclose(fid);
                    fid = fopen([file, datafileextension],'rt');
                    cell = textscan(fid,'%s','whitespace','','BufSize',round(f.bytes+(f.bytes*0.2)));
                end
            end
            fclose(fid);
            cont = cell2mat(cell{1});

            % read labels from rs3 file
            % initialize labels
            labels = num2cell(1:nChannels);

            for i = 1:nChannels
                text = sprintf('EEG%d',i);
                labels(i) = cellstr(text);
            end
                        
            % scan in cell 1 for LABELS (occurs four times per channel group)
            ix = strfind(cont,[char(10),'LABELS']);
            nt = size(ix,2);
            nc = 0;
            
            for i = 4:4:nt                                                      % loop over channel groups
                newlines = ix(i-1) + strfind(cont(ix(i-1)+1:ix(i)),char(10));   % newline
                last = nChannels - nc;
                for j = 1:min(last,size(newlines,2)-1)                          % loop over labels
                    text = cont(newlines(j)+1:newlines(j+1)-1);
                    if isempty(strfind(text,'END_LIST'))
                        nc = nc + 1;
                        labels(nc) = cellstr(text);
                    else 
                        break
                    end
                end 
            end

            %Search for Epoch Labels
            tixstar = strfind(cont,'EPOCH_LABELS START_LIST');
            tixstop = strfind(cont,'EPOCH_LABELS END_LIST');
            epochlabelslist = []; 
            if (~isempty(tixstar)) && (~isempty(tixstop))
                text = cont(tixstar:tixstop-1);
                tcell = textscan(text,'%s', 'delimiter','\n','whitespace','', 'headerlines', 1);
                epochlabelslist = tcell{1,1};
            end
            %Search for Epoch Information
            tixstar = strfind(cont,'EPOCH_INFORMATION START_LIST');
            tixstop = strfind(cont,'EPOCH_INFORMATION END_LIST');
            epochinformationlist = []; 
            if (~isempty(tixstar)) && (~isempty(tixstop))
                text = cont(tixstar:tixstop-1);
                tcell = textscan(text,'%d%d%d%d%d%d%d', 'delimiter','\n','headerlines', 1);
                epochinformationlist = cell2mat(tcell);
            end
            
            
            % read sensor locations from rs3 file
            % initialize sensor locations
            sensorpos = zeros(3,0);

            % scan in cell 1 for SENSORS (occurs four times per channel group)
            ix = strfind(cont,[char(10),'SENSORS']);
            nt = size(ix,2);
            nc = 0;

            for i = 4:4:nt                                                      % loop over channel groups
                newlines = ix(i-1) + strfind(cont(ix(i-1)+1:ix(i)),char(10));   % newline
                last = nChannels - nc;
                for j = 1:min(last,size(newlines,2)-1)                          % loop over labels
                    text = cont(newlines(j)+1:newlines(j+1)-1);
                    if isempty(strfind(text,'END_LIST'))
                        nc = nc + 1;
                        tcell = textscan(text,'%f');                           
                        posx = tcell{1}(1);
                        posy = tcell{1}(2);
                        posz = tcell{1}(3);
                        sensorpos = cat ( 2, sensorpos, [ posx; posy; posz ] );
                    else 
                        break
                    end
                end 
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % read events from cef/ceo file
            % initialize events
            ne = 0;                                                             % number of events
            events = zeros(4,0);
            annotations = cellstr('empty');

             % open file containing labels
            if (curryvers == 7)
                datafileextension = '.cef';
                datafileextensionalt = '.ceo';
            elseif (curryvers > 7)
                datafileextension = '.cdt.cef';
                datafileextensionalt = '.cdt.ceo';
            end
            
            % find appropriate file
            fid = fopen([file, datafileextension],'rt');
            if fid < 0
                fid = fopen([file, datafileextensionalt],'rt');
                f = dir([file, datafileextensionalt]);
            else
                f = dir([file, datafileextension]);
            end

            if fid >= 0                
                try
                    cell = textscan(fid,'%s','whitespace','','endofline','�');
                catch
                    fclose(fid);
                    fid = fopen([file, datafileextension],'rt');
                    if fid < 0
                        fid = fopen([file, datafileextensionalt],'rt');
                        f = dir([file, datafileextensionalt]);
                    else
                        f = dir([file, datafileextension]);
                    end
                    try
                        cell = textscan(fid,'%s','whitespace','','endofline','�','BufSize',round(f.bytes+(f.bytes*0.2)));
                    catch
                        fclose(fid);
                        fid = fopen([file, datafileextension],'rt');
                        if fid < 0
                            fid = fopen([file, datafileextensionalt],'rt');
                            f = dir([file, datafileextensionalt]);
                        else
                            f = dir([file, datafileextension]);
                        end
                        cell = textscan(fid,'%s','whitespace','','BufSize',round(f.bytes+(f.bytes*0.2)));
                    end
                end
                fclose(fid);
                cont = cell2mat(cell{1});

                % scan in cell 1 for NUMBER_LIST (occurs five times)
                ix = strfind(cont,'NUMBER_LIST');

                newlines = ix(4) - 1 + strfind(cont(ix(4):ix(5)),char(10));     % newline
                last = size(newlines,2)-1;
                for j = 1:last                                                  % loop over labels
                    text = cont(newlines(j)+1:newlines(j+1)-1);
                    tcell = textscan(text,'%d');                           
                    sample = tcell{1}(1);                                       % access more content using different columns
                    type = tcell{1}(3);
                    startsample = tcell{1}(5);
                    endsample = tcell{1}(6);
                    ne = ne + 1;
                    events = cat ( 2, events, [ sample; type; startsample; endsample ] );
                end

                % scan in cell 1 for REMARK_LIST (occurs five times)
                ix = strfind(cont,'REMARK_LIST');
                na = 0;

                newlines = ix(4) - 1 + strfind(cont(ix(4):ix(5)),char(10));     % newline
                last = size(newlines,2)-1;
                for j = 1:last                                                  % loop over labels
                    text = cont(newlines(j)+1:newlines(j+1)-1);
                    na = na + 1;
                    annotations(na) = cellstr(text);
                end    
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % read dat file
            if (curryvers == 7)
                datafileextension = '.dat';
            elseif (curryvers > 7)
                datafileextension = '.cdt';
            end
            
            if nASCII == 1
                fid = fopen([file, datafileextension],'rt');
                if (fid == -1)
                   error('Error in loadcurry(): Unable to open file.') 
                end
                f = dir([file, datafileextension]);
                try
                    fclose(fid);
                    fid = fopen([file, datafileextension],'rt');
                    cell = textscan(fid,'%f',nChannels*nSamples*nTrials);
                catch
                    fclose(fid);
                    fid = fopen([file, datafileextension],'rt');
                    cell = textscan(fid,'%f',nChannels*nSamples*nTrials, 'BufSize',round(f.bytes+(f.bytes*0.2)));
                end
                fclose(fid);
                data = reshape([cell{1}],nChannels,nSamples*nTrials);
            else
                fid = fopen([file, datafileextension],'rb');
                if (fid == -1)
                   error('Error in loadcurry(): Unable to open file.') 
                end
                data = fread(fid,[nChannels,nSamples*nTrials],'float32');
                fclose(fid);
            end

            % transpose?
            if nMultiplex == 1
                data = data';
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % time axis
            time = linspace(fOffsetUsec/1000,fOffsetUsec/1000+(nSamples*nTrials-1)*1000/fFrequency,nSamples*nTrials);

            %% Created to take this data and place it into EEGLAB format (v13.4.4b)
            
            currytime = double(linspace(fOffsetUsec/1000,fOffsetUsec/1000+(nSamples*nTrials-1)*1000/fFrequency,nSamples*nTrials));
            
            % Handle Epoched Datasets
            if (nTrials > 1)
                origdata = double(data);
                newdata = NaN(nChannels, nSamples, nTrials);
                startpoint = 1;
                stoppoint = startpoint + nSamples - 1;
                for cC = 1:nTrials
                    newdata(:,:,cC) = data(:,startpoint:stoppoint);
                    startpoint = startpoint + nSamples;
                    stoppoint = startpoint + nSamples - 1;
                end
                data = newdata;
                time = linspace(0,nSamples/fFrequency,nSamples);
                time = time + (fOffsetUsec/1000000);
            end
            
            EEG.setname = 'Neuroscan Curry file';
            if (curryvers == 7)
                datafileextension = '.dap';
            elseif (curryvers > 7)
                datafileextension = '.cdt';
            end
            EEG.filename = [name, datafileextension];
            EEG.filepath = filepath;
            EEG.comments = sprintf('Original file: %s%s', filepath, [name, datafileextension]);
            EEG.ref = 'Common';
            EEG.trials = nTrials;
            EEG.pnts = nSamples;
            EEG.srate = fFrequency;
            EEG.times = time;
            EEG.data = double(data);
            EEG.xmin = min(EEG.times);
            EEG.xmax = (EEG.pnts-1)/EEG.srate+EEG.xmin;
            EEG.nbchan = size(EEG.data,1);
            EEG.urchanlocs = [];
            EEG.chaninfo.plotrad = [];
            EEG.chaninfo.shrink = [];
            EEG.chaninfo.nosedir = '+X';
            EEG.chaninfo.nodatchans = [];
            EEG.chaninfo.icachansind = [];
            
            % Populate channel labels
            EEG.chanlocs = struct('labels', [], 'ref', [], 'theta', [], 'radius', [], 'X', [], 'Y', [], 'Z', [],'sph_theta', [], 'sph_phi', [], 'sph_radius', [], 'type', [], 'urchan', []);
            for cC = 1:(numel(labels))
                EEG.chanlocs(cC).labels = char(upper(labels(cC))); % Convert labels to uppercase and store as character array string
                EEG.chanlocs(cC).urchan = cC;
            end

            if strcmpi(r.CurryLocations, 'True')
                % Populate channel locations
                % LPS sensor system:
                % from right towards left, 
                % from anterior towards posterior, 
                % from inferior towards superior

                % MATLAB/EEGLAB system:
                % x is towards the nose, 
                % y is towards the left ear, 
                % z towards the vertex.

                try, sensorpos; booler = 0; catch; booler = 1; end
                if (booler == 0)
                    for cC = 1:size(sensorpos,2)
                       EEG.chanlocs(cC).Y = sensorpos(1,cC); 
                       EEG.chanlocs(cC).X = sensorpos(2,cC)*-1; 
                       EEG.chanlocs(cC).Z = sensorpos(3,cC); 
                    end
                    % Populate other systems based upon these values
                    EEG.chanlocs = convertlocs( EEG.chanlocs, 'auto');
                end
                EEG.history = sprintf('%s\nEEG = loadcurry(''%s%s'', ''CurryLocations'', ''True'');', EEG.history, filepath, [name, datafileextension]); 
            else
                % Use default channel locations
                try
                    tempEEG = EEG; % for dipfitdefs
                    dipfitdefs;
                    tmpp = which('eeglab.m');
                    tmpp = fullfile(fileparts(tmpp), 'functions', 'resources', 'Standard-10-5-Cap385_witheog.elp');
                    userdatatmp = { template_models(1).chanfile template_models(2).chanfile  tmpp };
                    try
                        [T, tempEEG] = evalc('pop_chanedit(tempEEG, ''lookup'', userdatatmp{1})');
                    catch
                        try
                            [T, tempEEG] = evalc('pop_chanedit(tempEEG, ''lookup'', userdatatmp{3})');
                        catch
                            booler = 1;
                        end
                    end
                    EEG.chanlocs = tempEEG.chanlocs;
                catch
                    booler = 1;
                end
                EEG.history = sprintf('%s\nEEG = loadcurry(''%s%s'');', EEG.history, filepath, [name, datafileextension]);
            end
            
            % Place impedance values within the chanlocs structure
            try
                if ~isempty(impedancematrix)
                    if (size(impedancematrix,2) == size({EEG.chanlocs.labels},2)) % number of channels matches number of impedances
                        impedancematrix(impedancematrix == -1) = NaN; % screen for missing values
                        impedancelist = nanmedian(impedancematrix);
                        for cC = 1:size({EEG.chanlocs.labels},2)
                           EEG.chanlocs(cC).impedance = impedancematrix(1,cC)/1000; 
                           EEG.chanlocs(cC).median_impedance = impedancelist(1,cC)/1000;
                        end
                    end
                end
            catch
                booler = 1;
            end
            
            
            % Handle Epoched Datasets
            if (nTrials > 1)
                
                [~, zeropoint] = min(abs(EEG.times));
                EEG.data = origdata; % restore original data
                EEG.trials = 1;
                EEG.pnts = size(EEG.data,2);
                EEG.xmin = 0;
                EEG.xmax = (EEG.pnts-1)/EEG.srate+EEG.xmin;
                EEG.times = linspace(EEG.xmin,EEG.xmax,EEG.pnts);
                trigchannel = zeros(1, EEG.pnts);
                
                tempevent = struct('type', [], 'latency', [], 'urevent', [], 'label', []);
                startpoint = 1;
                currentline = 1;
                for cC = 1:nTrials
                    
                    % See if there are actual event information to add
                    if size(epochinformationlist,1) > 0
                        
                        tempevent(currentline).label = epochlabelslist{cC,1};
                        tempevent(currentline).urevent = cC;
                        tempevent(currentline).type = epochinformationlist(cC,3);
                        tempevent(currentline).latency = double(startpoint+zeropoint-1);
                        trigchannel(startpoint+zeropoint-1) = epochinformationlist(cC,3);
                        
                        currentline = currentline + 1;
                    end
                    
                    if (cC < nTrials)
                        % place boundary event at the end
                        tempevent(currentline).type = 'boundary';
                        tempevent(currentline).latency = double(startpoint+nSamples-1);

                        currentline = currentline + 1;
                    end
                    startpoint = startpoint + nSamples;
                end
                
                EEG.event = tempevent; 
                EEG.urevent = struct('type', [], 'latency', []);
                
                % place triggers in channel
                if (sum(trigchannel) > 0)
                    if isempty(find(strcmpi({EEG.chanlocs.labels},'Trigger')))
                        EEG.data(end+1,:) = trigchannel;
                        EEG.chanlocs(end+1).labels = 'TRIGGER';
                    else
                        % a trigger channel already exists likely
                        % containing response or movement type events that
                        % occurred during the epoch. 
                        
                        chanindex = find(strcmpi({EEG.chanlocs.labels},'Trigger'));
                        % Remove baseline from trigger channel
                        EEG.data(chanindex,:) = EEG.data(chanindex,:)-EEG.data(chanindex,1);

                        tempun = find(trigchannel > 0); % find all new events
                        for cC = 1:size(tempun,2) 
                            if ~(EEG.data(chanindex, tempun(cC)) == trigchannel(tempun(cC)))
                                % the marker is unique
                                EEG.data(chanindex, tempun(cC)) = trigchannel(tempun(cC)); % store the new value
                            end
                        end
                    end
                end
            else
                EEG.event = struct('type', [], 'latency', [], 'urevent', []);
                EEG.urevent = struct('type', [], 'latency', []);
            end
            
            % Data should now be in continuous format
            % previously epoched data will have events already loaded
            % previously continuous data should have an empty event
            % structure
            
            % Populate Event List
            if ~isempty(events)
                % Curry recorded events
                if (size(EEG.event,2) == 1)
                    currentline = 1;
                else
                    currentline = size(EEG.event,2) + 1;
                end
                
                for cC = 1:size(events,2)
                    % obtain the sampling point - verified against the
                    % curry time points
                    [~, tindx] = min(abs(currytime - double(events(1,cC))));
                    
                    % see if the event is already marked
                    samppoint = find([EEG.event.latency] == tindx);
                    boolcont = 1;
                    if ~isempty(samppoint)
                        if ~(EEG.event(samppoint).type == events(2,cC))
                            % the events are different
                            if (isempty(find([EEG.event.latency] == (tindx+1))))
                                % move marker by 1 sample
                                tindx = tindx + 1;
                            elseif (isempty(find([EEG.event.latency] == (tindx-1))))
                                % move marker back by 1 sample
                                tindx = tindx - 1;
                            elseif (isempty(find([EEG.event.latency] == (tindx+2))))
                                % move marker by 2 samples
                                tindx = tindx + 2;
                            elseif (isempty(find([EEG.event.latency] == (tindx-2))))
                                % move marker back by 2 samples
                                tindx = tindx - 2;
                            else
                                tindx = tindx - 0.5; % half sample
                            end
                        else
                            % sample has been marked already
                            boolcont = 0;
                        end
                    end
                    
                    if (boolcont == 1)
                        EEG.event(currentline).urevent = cC;
                        EEG.event(currentline).type = events(2,cC);
                        EEG.event(currentline).latency = double(tindx);
                        currentline = currentline + 1;
                    end
                end
                [~,index] = sortrows([EEG.event.latency].'); EEG.event = EEG.event(index); clear index
            end
            
            
            % Event list should be populated either by the event list read
            % in or by translating the epoch information
            % Validate and Update the trigger channel if available
            
            % Determine if Trigger Channel is present
            chanindex = find(strcmpi({EEG.chanlocs.labels},'Trigger'));
            if ~isempty(chanindex)

                % Remove baseline from trigger channel
                EEG.data(chanindex,:) = EEG.data(chanindex,:)-EEG.data(chanindex,1);

                % Populate list based on values above 0, triggers may last more than one sample
                templat = find(EEG.data(chanindex,:) > 0);
                templatrem = [];
                for cC = 2:numel(templat)
                    % If the sampling point is one off
                    if ((templat(cC)-1) == templat(cC-1))
                       templatrem(end+1) = templat(cC);
                    end
                end
                templat = setdiff(templat,templatrem);
                if ~isempty(templat)
                    % Populate event list
                    for cC = 1:numel(templat)
                        tindx = double(templat(cC));
                        % see if the event already exists
                        samppoint = find([EEG.event.latency] == tindx);
                        boolcont = 1;
                        if ~isempty(samppoint)
                            if ~(EEG.event(samppoint).type == EEG.data(chanindex,templat(cC)))
                                % the events are different
                                if (isempty(find([EEG.event.latency] == (tindx+1))))
                                    % move marker by 1 sample
                                    tindx = tindx + 1;
                                elseif (isempty(find([EEG.event.latency] == (tindx-1))))
                                    % move marker back by 1 sample
                                    tindx = tindx - 1;
                                elseif (isempty(find([EEG.event.latency] == (tindx+2))))
                                    % move marker by 2 samples
                                    tindx = tindx + 2;
                                elseif (isempty(find([EEG.event.latency] == (tindx-2))))
                                    % move marker back by 2 samples
                                    tindx = tindx - 2;
                                else
                                    tindx = tindx - 0.5; % half sample
                                end
                            else
                                % events is already marked
                                boolcont = 0;
                            end
                        end
                        
                        if (boolcont == 1)
                            try
                                EEG.event(cC).urevent = cC;
                                EEG.event(cC).type = EEG.data(chanindex,templat(cC));
                                EEG.event(cC).latency = double(tindx);
                            catch
                                boolpass = 1;
                            end
                        end
                    end
                end
                [~,index] = sortrows([EEG.event.latency].'); EEG.event = EEG.event(index); clear index
                
                % Reverse and make sure events are all in trigger channel
                %try
                    for cC = 1:size(EEG.event,2)
                        % verify that it is not a boundary event
                        if ~(strcmpi(EEG.event(cC).type,'boundary'))
                            % verify that it is not a string type
                            if ~(isstring(EEG.event(cC).type))
                                samppoint = EEG.event(cC).latency;
                                if ~(EEG.data(chanindex,samppoint) == EEG.event(cC).type)
                                    % values are not equal
                                    EEG.data(chanindex,samppoint) = EEG.event(cC).type;
                                end
                            end
                        end
                    end
                %catch
                    boolpass = 1;
                %end
            end
                
            % Remove Trigger Channel
            if ~isempty(find(strcmpi(labels,'Trigger')))
                if ~strcmpi(r.KeepTriggerChannel, 'True')
                    EEG.data(find(strcmpi(labels,'TRIGGER')),:) = [];
                    EEG.chanlocs(find(strcmpi(labels,'TRIGGER'))) = [];
                end
            end

            EEG.nbchan = size(EEG.data,1);
            [T, EEG] = evalc('eeg_checkset(EEG);');
            EEG.history = sprintf('%s\nEEG = eeg_checkset(EEG);', EEG.history);

        end
    end   
end