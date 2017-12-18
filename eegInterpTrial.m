function [data, chanInterp, trialInterp, totInterp, propInterp,...
    interpMat, interpNeigh, cantInterp] =...
    eegInterpTrial(data, art, distance, nb)

    numBad = 0;
    numInterp = 0;
    interpMat = false(length(data.label), length(data.trial));
    interpNeigh = cell(length(data.label), length(data.trial));
    cantInterp = false(length(data.label), length(data.trial));

    if ~exist('distance', 'var') || isempty(distance)
        distance = 50;
    end
    
    % get ft neighbours structure for determining electrodes to intepolate
    % from 
    if ~exist('nb', 'var')
        cfg = [];
        cfg.method = 'distance';
        cfg.layout = data.elec;
        cfg.neighbourdist = distance;
        nb = ft_prepare_neighbours(cfg, data); 
    end
    
    % flags to store which trials/channels were interpolated/excluded
    interp = false(length(data.label), length(data.trial));
    excl = false(length(data.label), length(data.trial));
    
    % loop through trials
    numTr = size(data.trial, 2);
    for tr = 1:numTr
        
        % check that there are some channels with artefacts on this current
        % trial
        if ~any(art.matrix(:, tr)), continue, end
        
        % select data from current trial
        cfg = [];
        cfg.trials = false(numTr, 1);
        cfg.trials(tr) = true;
        data_stripped = rmfieldIfPresent(data,...
            {'interp', 'interpNeigh', 'art', 'chanExcl'});
        tmp = ft_selectdata(cfg, data_stripped);
        
        % extract channels with artefacts on this trial
        bad = art.matrix(:, tr);
        
        % find non-bad neighbours
        [canInterp, canInterpLabs, canInterpNb, canInterpSmry] =...
            eegAR_FindInterpChans(data, bad, false, nb);
        
        % store indices of channels that can't be interpolated
        cantInterp(:, tr) = bad & ~canInterp;
                
        if any(canInterp)
            
            % interpolate
            cfg = [];
            cfg.method = 'spline';
            cfg.badchannel = canInterpLabs;
            cfg.neighbours = canInterpNb;
            tmpi = ft_channelrepair(cfg, tmp);
            interpMat(canInterp, tr) = true;
            interpNeigh(canInterp, tr) = {canInterp};
            
            % replace original trial data
            data.trial{tr} = tmpi.trial{:};
            
            % update flags
            interp(canInterp, tr) = true;
            excl(bad & ~canInterp, tr) = true;
            
        end

    end
    
    % summarise interpolation
    chanInterp = sum(interp, 2);                    % num channels with any trials interpolated
    trialInterp = sum(interp, 1);                   % num trials with any channels interpolated
    totInterp = sum(interp(:));                     % total num of chan x trial interpolations
    propInterp = totInterp / length(interp(:));     % prop of chan x trial interpolations
    
end