function curryStruct = LoadCurryDataFile(varargin)
% Load Curry cdt/dat with corresponding dpa/dap/rs3 files into MATLAB and display waveforms
%
% Call prompting user with open-file selection window:
%
%     curryStruct = LoadCurryDataFile() 
%
% Call using optional inputs (input order is mandatory):
%
%     curryStruct   = LoadCurryDataFile(fullFileName, showPlot, verbose)
% 
%     fullFileName  -   Full path to Curry file (default = [])
%     showPlot      -   (0 or 1) Display waveform plot of entire file (default = 1)
%     verbose       -   (0 or 1) Show warning/error message-boxes (default = 1)
%
% Output CurryStruct contains:
%
%     data            -  functional data matrix (e.g. EEG, MEG) with dimensions (channels, samples x trials)               
%     numChannels     -  number of channels
%     numSamples      -  number of samples
%     samplingFreqHz  -  sampling frequency in Hz
%     numTrials       -  number of trials
%     trigOffsetUsec  -  trigger offset in microseconds
%     labels          -  channel labels 
%     sensorLocations -  channel locations matrix [x,y,z]
%     events          -  events matrix where every row is: [event latency, event type, event start, event stop]
%     annotations     -  events annotations
%     epochInfo       -  epochs matrix where every row is: [number of averages, total epochs, type, accept, correct, response, response time]
%     epochLabels     -  epoch labels
%     impedanceMatrix -  impedance matrix with max size (channels, 10), i.e. last ten impedance measurements (unused/empty measurements marked as NaN)
%
%   Received from Compumedics Neuroscan Curry Helpdesk, October 27, 2021
%   
%   revision 0.1 - 
%               - Error handling
%               - Bug fixes
%               - Release goes through more complete testing procedure
%

curryStruct = [];
Title = 'Open Curry Data File';

% assign optional input arguments
if ~isempty(varargin)
    inputArgs = struct('fullFileName',[],'showPlot',1, 'verbose', 1);
    for i = 1:nargin
        if i == 1 && (ischar(varargin{i}) || isstring(varargin{i}))
            inputArgs.fullFileName = char(varargin{i});
        elseif i == 2 && isnumeric(varargin{i})
            inputArgs.showPlot = varargin{i};
        elseif i == 3 && isnumeric(varargin{i})
            inputArgs.verbose = varargin{i};
        else
            errorHandling('Invalid input parameter',inputArgs.verbose,'error');
        end
    end
end

% default input arguments
if ~exist('inputArgs', 'var')
    inputArgs.fullFileName = [];
    inputArgs.showPlot = 1;
    inputArgs.verbose = 1;
end

if isempty(inputArgs.fullFileName)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % ask user to specify file
    [fileName,pathName,filterIndex] = uigetfile({'*.cdt;*.dat' 'All Curry Data Files';'*.cdt' 'Curry 8, Curry 9 Data Files'; '*.dat' 'Curry 7 Data Files'},Title,pwd);
    
    % cancel button
    if ( filterIndex == 0 )
       return;
    end

    if ( fileName == 0 )
        errorHandling('Invalid file name',inputArgs.verbose,'error');
    end
    
    dataFile = [pathName,fileName];
else
    dataFile = inputArgs.fullFileName;
end

[pathName,fileName,extension] = fileparts(dataFile);

if ( strcmpi ( extension,'.dat' ) )
    if ispc
        baseName = [pathName,'\',fileName];
    else
        baseName = [pathName,'/',fileName];
    end
    parameterFile = [baseName,'.dap'];
    labelFile = [baseName,'.rs3'];
    eventFile = [baseName,'.cef'];
    eventFile2 = [baseName,'.ceo'];
elseif ( strcmpi ( extension,'.cdt' ) )
    parameterFile = [dataFile,'.dpa'];
    parameterFile2 = [dataFile,'.dpo'];
    eventFile = [dataFile,'.cef'];
    eventFile2 = [dataFile,'.ceo'];
else
    errorHandling('Unsupported file name (choose a .cdt or .dat file)',inputArgs.verbose,'error');
end
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% open parameter file
fid = fopen(parameterFile,'rt');

% open alternative parameter file
if fid < 0
    fid = fopen(parameterFile2,'rt');
end

if fid < 0
    errorHandling('Parameter file not found (make sure .dap, .dpa or .dpo file exists)',inputArgs.verbose,'error');
end

cell = textscan(fid,'%s','whitespace','','endofline','§');
fclose(fid);
cont = cell2mat(cell{1});

% check for compressed file format
ctok = 'DataGuid';
ix = strfind(cont,ctok);
if ~isempty ( ix )
    text = sscanf(cont(ix+numel(ctok):end),' = %s');    
    if (strcmp(text, '{2912E8D8-F5C8-4E25-A8E7-A1385967DA09}') == 1)
        errorHandling('Unsupported data format (compressed). Use Curry to convert this file to Raw Float format.',...
            inputArgs.verbose,'error');
    end
end

% read parameters from parameter file
% tokens (second line is for Curry 6 notation)
tok = { 'NumSamples'; 'NumChannels'; 'NumTrials'; 'SampleFreqHz';  'TriggerOffsetUsec';  'DataFormat'; 'DataSampOrder';   'SampleTimeUsec';
        'NUM_SAMPLES';'NUM_CHANNELS';'NUM_TRIALS';'SAMPLE_FREQ_HZ';'TRIGGER_OFFSET_USEC';'DATA_FORMAT';'DATA_SAMP_ORDER'; 'SAMPLE_TIME_USEC'};

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
numSamples    = a(1)+a(1+nt/2);
numChannels   = a(2)+a(2+nt/2);
numTrials     = a(3)+a(3+nt/2);
samplingFreq  = a(4)+a(4+nt/2);
offsetUsec    = a(5)+a(5+nt/2);
isASCII       = a(6)+a(6+nt/2);
multiplex     = a(7)+a(7+nt/2);
sampleTime    = a(8)+a(8+nt/2);

if ( samplingFreq == 0 && sampleTime ~= 0 )
    samplingFreq = 1000000 / sampleTime;
end

% try to guess number of samples based on datafile size
if numSamples < 0
    if isASCII == 1
        errorHandling(...
            'Number of samples cannot be guessed from ASCII data file. Use Curry to convert this file to Raw Float format.',...
            inputArgs.verbose, 'error');
    else
        fileInfo = dir(dataFile);
        fileSize = fileInfo.bytes;
        numSamples = fileSize / (4 * numChannels * numTrials);
    end       
end

%Search for Impedance Values
tixstar = strfind(cont,'IMPEDANCE_VALUES START_LIST');
tixstop = strfind(cont,'IMPEDANCE_VALUES END_LIST');

impedanceList = []; 
impedanceMatrix = [];

if (~isempty(tixstar)) && (~isempty(tixstop))
    text = cont(tixstar:tixstop-1);
    tcell = textscan(text,'%s');
    tcell = tcell{1,1};
    for tcC = 1:size(tcell,1)
       tcell{tcC} = str2num(tcell{tcC}); % data was read in as strings - force to numbers
       if ~isempty(tcell{tcC}) % skip if it is not a number
           impedanceList(end+1) = tcell{tcC};
       end
    end

    % Curry records last 10 impedances
    impedanceMatrix = reshape(impedanceList,[(size(impedanceList,2)/10),10])';
    impedanceMatrix(impedanceMatrix == -1) = NaN; % screen for missing
end
            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% open label file
if ( strcmpi ( extension,'.dat' ) )
    fid = fopen(labelFile,'rt');
    if fid < 0
        errorHandling('Unable to open label file from Curry legacy format.', inputArgs.verbose, 'warn');
        cont = '';
    else
        cell = textscan(fid,'%s','whitespace','','endofline','§');
        fclose(fid);
        cont = cell2mat(cell{1});
    end
end

% read labels from label file
% initialize labels
labels = num2cell(1:numChannels);

for i = 1:numChannels
    text = sprintf('EEG%d',i);
    labels(i) = cellstr(text);
end

% scan in cell 1 for LABELS (occurs four times per channel group)
ix = strfind(cont,[char(10),'LABELS']);
nt = size(ix,2);
numOcc = 4;         % number of token occurences per channel group
nc = 0;

for i = numOcc:numOcc:nt                                            % loop over channel groups
    newLines = ix(i-1) + strfind(cont(ix(i-1)+1:ix(i)),char(10));   % newline
    last = numChannels - nc;
    for j = 1:min(last,size(newLines,2)-1)                          % loop over labels
        text = cont(newLines(j)+1:newLines(j+1)-1);
        if isempty(strfind(text,'END_LIST'))
            nc = nc + 1;
            labels(nc) = cellstr(text);
        else 
            break
        end
    end 
end

% read sensor locations from label file
% initialize sensor locations
sensorLocations = zeros(3,0);

% scan in cell 1 for SENSORS (occurs four times per channel group)
ix = strfind(cont,[char(10),'SENSORS']);
nt = size(ix,2);    % token occurences   
nc = 0;
numOcc = 4;         % number of token occurences per channel group
numChansWithPos = 0;
groupPosPerSensor = zeros(1,nt/numOcc);

for i = numOcc:numOcc:nt                                            % firs pass over channel groups for finding sensorpos size
    newLines = ix(i-1) + strfind(cont(ix(i-1)+1:ix(i)),char(10));     
    text = cont(newLines(1)+1:newLines(2)-1);
    posPerSensor = length(cell2mat(textscan(text,'%f')));           % either one position per sensor (EEG, MEG) or two positions (MEG)
    groupPosPerSensor(i/numOcc) =  posPerSensor;
    numChansWithPos = numChansWithPos + (numel(newLines)-1);
end

maxPosPerSensor = max(groupPosPerSensor);

if (maxPosPerSensor == 3 || maxPosPerSensor == 6) && ...                % 3 means one pos. per sensor (MEG,EEG). 6 is two pos. per sensor (MEG)
    (numChansWithPos > 0 && numChansWithPos <= numChannels)
    
    sensorLocations = zeros(maxPosPerSensor, numChansWithPos);
    
    for i = numOcc:numOcc:nt                                            % loop over channel groups
        newLines = ix(i-1) + strfind(cont(ix(i-1)+1:ix(i)),char(10));   % newline
        last = numChannels - nc;
        posPerSensor = groupPosPerSensor(i/numOcc);
        for j = 1:min(last,size(newLines,2)-1)                          % loop over labels
            text = cont(newLines(j)+1:newLines(j+1)-1);
            if isempty(strfind(text,'END_LIST'))
                nc = nc + 1;
                location = cell2mat(textscan(text,'%f'));
                sensorLocations(1:posPerSensor,nc) = location;
            else
                break
            end
        end
    end
end

% search for epoch labels
if ( strcmpi ( extension,'.dat' ) )
    fid = fopen(parameterFile,'rt');
    cell = textscan(fid,'%s','whitespace','','endofline','§');
    fclose(fid);
    cont = cell2mat(cell{1});
end

tixstar = strfind(cont,'EPOCH_LABELS START_LIST');
tixstop = strfind(cont,'EPOCH_LABELS END_LIST');

epochLabelsList = []; 

if (~isempty(tixstar)) && (~isempty(tixstop))
    text = cont(tixstar:tixstop-1);
    tcell = textscan(text,'%s', 'delimiter','\n','whitespace','', 'headerlines', 1);
    epochLabelsList = tcell{1,1};
end

% search for epoch information
tixstar = strfind(cont,'EPOCH_INFORMATION START_LIST');
tixstop = strfind(cont,'EPOCH_INFORMATION END_LIST');

epochInformationList = []; 

if (~isempty(tixstar)) && (~isempty(tixstop))
    text = cont(tixstar:tixstop-1);
    tcell = textscan(text,'%d%d%d%d%d%d%d', 'delimiter','\n','headerlines', 1);
    epochInformationList = cell2mat(tcell);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read events from event file
% initialize events and annotations
ne = 0;                             % number of events
events = zeros(4,0);
annotations = cellstr('empty');

% find appropriate file
fid = fopen(eventFile,'rt');

if fid < 0
    fid = fopen(eventFile2,'rt');
end

if fid >= 0
    cell = textscan(fid,'%s','whitespace','','endofline','§');
    fclose(fid);
    cont = cell2mat(cell{1});

    % scan in cell 1 for NUMBER_LIST (occurs five times)
    ix = strfind(cont,'NUMBER_LIST');
    
    newLines = ix(4) - 1 + strfind(cont(ix(4):ix(5)),char(10));     % newline
    last = size(newLines,2)-1;
    for j = 1:last                                                  % loop over labels
        text = cont(newLines(j)+1:newLines(j+1)-1);
        tcell = textscan(text,'%d');                           
        sample = tcell{1}(1);                                       % access more content using different columns
        type = tcell{1}(3);
        startSample = tcell{1}(5);
        endSample = tcell{1}(6);
        ne = ne + 1;
        events = cat ( 2, events, [ sample; type; startSample; endSample ] );
    end
    
    % scan in cell 1 for REMARK_LIST (occurs five times)
    ix = strfind(cont,'REMARK_LIST');
    na = 0;
    
    newLines = ix(4) - 1 + strfind(cont(ix(4):ix(5)),char(10));     % newline
    last = size(newLines,2)-1;
    for j = 1:last                                                  % loop over labels
        text = cont(newLines(j)+1:newLines(j+1)-1);
        na = na + 1;
        annotations(na) = cellstr(text);
    end    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% read data file

if isASCII == 1
    fid = fopen(dataFile,'rt');
else
    fid = fopen(dataFile,'rb');
end

if fid < 0
    errorHandling('Curry data file not found (make sure .cdt or .dat file exists)', inputArgs.verbose, 'error');
end

if isASCII == 1
    cell = textscan(fid,'%f',numChannels*numSamples*numTrials);
    readSamples = floor(length([cell{1}]) / (numChannels*numTrials));
    data = reshape(cell{1}(1:numChannels*readSamples*numTrials),numChannels,readSamples*numTrials);
else
    [data, count] = fread(fid,[numChannels,numSamples*numTrials],'float32');
    readSamples = floor(count / (numChannels*numTrials));
    data = data(:,1:readSamples*numTrials);
end

fclose(fid);

if numSamples ~= readSamples
    if readSamples == 0
        errorHandling('Failed to read Curry data file. File is empty.', inputArgs.verbose, 'error');
    else
        errorHandling('Inconsistent number of samples. File may be read incompletely.', inputArgs.verbose, 'warn');
        numSamples = readSamples;
    end
end

% transpose?
if multiplex == 1
    data = data';
end

if inputArgs.showPlot == 1
    % time axis
    time = linspace(offsetUsec/1000,offsetUsec/1000+(numSamples*numTrials-1)*1000/samplingFreq,numSamples*numTrials);
    
    % simple plot
    subplot(2,1,1);
    plot(time,data); axis tight
    title([fileName, extension])
    
    % stacked plot
    subplot(2,1,2);
    range = max([abs(min(min(data))) abs(max(max(data)))]);
    shift = linspace((numChannels-1)*range*0.3,0,numChannels);
    plot(time,data+repmat(shift,numSamples*numTrials,1)'); axis tight
    set(gca,'ytick',flip(shift),'yticklabel',flip(labels),'GridLineStyle',':','XGrid','on','YGrid','off');
    ylim([min(min(data+repmat(shift,numSamples*numTrials,1)')) max(max(data+repmat(shift,numSamples*numTrials,1)'))]);
end

% output
curryStruct = struct(   'data',             data, ...
                        'numChannels',      numChannels, ...
                        'numSamples',       numSamples, ...        
                        'samplingFreqHz',   samplingFreq, ...
                        'numTrials',        numTrials, ...
                        'trigOffsetUsec',   offsetUsec,...
                        'labels',           {labels}, ... 
                        'sensorLocations',  sensorLocations, ...
                        'events',           events, ...
                        'annotations',      {annotations}, ...
                        'epochInfo',        epochInformationList, ...
                        'epochLabels',      {epochLabelsList}, ...
                        'impedanceMatrix',  impedanceMatrix);
end


function errorHandling(msg, showBox, type)

Title = 'Open Curry Data File';

if showBox
    msgbox(msg, Title, type)
end

if strcmpi( type, 'error')
    error(msg);
else
    warning(msg);
end

end
