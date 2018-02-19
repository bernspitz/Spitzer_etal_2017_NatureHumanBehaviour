function results = rdm_computeConditionCoeffs(eegMat,behavVect)
%% RESULTS = RDM_COMPUTECONDITIONCOEFFS(EEGMAT,BEHAVVECT)
%
% regresses the eeg signal on the trial-by-condition design matrix for all electrodes and points in time
%
% eegMat = electrode-by-time-by-trial matrix of raw voltages
% behavVect = trial-vector (indicating the condition on each trial)
%
% (c) Timo Flesch, 2016
 
results = struct(); 
results.betas   = [];
results.resids  = [];
 
% set up design matrix
conditions = unique(behavVect)';
dmat = zeros(size(behavVect,1),length(conditions));
for c = 1:length(conditions)
    dmat(behavVect==conditions(c),c) = 1;   
end
 
 
% for all electrodes and time points: run regression
for el = 1:size(eegMat,1)
    for t = 1:size(eegMat,2)
       [betas,~,resid] = regress(zscore(squeeze(eegMat(el,t,:))),dmat);
       results.betas(el,t,:) = betas; 
       results.resids(el,t,:) = resid;
    end       
end
end

