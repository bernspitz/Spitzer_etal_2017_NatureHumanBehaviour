%% RSA; requires SPM and Representational Similarity Toolbox (Nili et al., 2014)
clear all; restoredefaultpath; addpath('C:\work\spm12\'); spm('defaults', 'eeg'); 
anapath='C:\work\numcum_analysis\';
anadir=[anapath 'proc10_home\']; %mkdir(anadir);
prefix='fTfMdnc';

savefiles=0; % save RDM (0: no; 1: yes)
savepath='C:\Users\Berni\Dropbox\numcum\ms\NHB_rev1\eeg_check\RDMfiles\';
savelab='RDM';
modlabs={'vis';'aud'};

addpath(genpath('C:\Users\Berni\Dropbox\numcum\ms\scripts_abseeg'));
addpath(genpath('C:\Users\Berni\Dropbox\numcum\scripts\rsatoolbox')); % includes TIFL scripts/tools
subjects={'01';'02';'03';'04';'05';'06';'07';'08';'09';'10';'11';'12';'13';'14';'15';'16';'17';'18';'19';'20';'21';'22';'23';'24'}; %N=24

periT=[-0.1 0.9];
afxthr=80;
BL=[-0.1 0];
smooth=[12]; % 5: 20 ms;  13: ~50 ms; 25: ~100 ms
withindeco=0;
pcaredu=1;
tau=1;

tic; cd(anadir);

for selmod=1:2
    for sub=1:length(subjects)

        disp(['loading SPM M/EEG file subject ' subjects{sub}])
        D=spm_eeg_load([anadir prefix  subjects{sub} '.mat']); 
        subnum=str2num(subjects{sub});

    %%  get stimulus sample/time definition
        disp('assembling stimulus/sample & time definition')
        % isolate experiment triggers from artefact markers
        tmp=D.events; 
        evt=[]; tim=[]; smp=[]; trg=0; 
        for i=1:length(tmp)
            if strmatch(tmp(i).type, 'STATUS', 'exact') & isnumeric(tmp(i).value)
                trg=trg+1;
                evt(trg)=tmp(i).value;
                tim(trg)=tmp(i).time;
            end
        end
        nevent=tmp;   

        % get trials (events & time info)
        stimdef=[]; stimtim=[]; trinum=0;
        for i=1:length(evt)-14

            modcode=[]; rt=[]; resp=[]; 
            if sum(evt(i+1:i+10)>10)==10 & evt(i+11)==3 & evt(i+12)==4 & ismember(evt(i+13),[6 10]) & ismember(evt(i+14),[210 214 215])
                rt=1000*(tim(i+12)-tim(i+10))-350;
                resp=evt(i+13);
                if evt(i)==1 | evt(i)==100 % visual (if trig 1 got lost on block start -> 100) 
                    modcode=1;
                elseif evt(i)==2 % auditory
                    modcode =2;
                end
            % for those trials without a trigger '3': 
            elseif sum(evt(i+1:i+10)>10)==10 & evt(i+11)==4 & ismember(evt(i+12),[6 10]) & ismember(evt(i+13),[210 214 215]) 
                rt=1000*(tim(i+11)-tim(i+10))-350;
                resp=evt(i+12);
                if evt(i)==1 | evt(i)==100 % visual (if trig 1 got lost on block start -> 100)
                    modcode=1;
                elseif evt(i)==2 % auditory
                    modcode=2;           
                end
            end

            if mod(subnum,2)
                resp=-resp+16; %shake da booty
            end
            resp=round(resp/6); % -> 1/2


            if ~isempty(modcode) % if current trial is valid
                trinum=trinum+1;
                catcount=sum(sign(evt(i+1:i+10)-110)==-1);
                for k=1:10

                    actevt=evt(i+k); % current trigger
                    acttim=tim(i+k); % current time

                    num=rem(actevt,10);% Number
                    cgy=sign(actevt-110); % Category
                    cgy=(cgy+1)./2+1; % -> 1/2

                    %assemble stim/sample & time definition 
                    stimdef=[stimdef; [modcode k cgy num resp round(rt) trinum catcount]];
                    stimtim=[stimtim; acttim];

                end
            end
        end

        sel=find(stimdef(:,1)==selmod); 
        stimdef=stimdef(sel,:);
        stimtim=stimtim(sel);

        % epoch data
        disp('epoching..');

        dat=D(find(~ismember([1:64],D.badchannels)),:); % remove bad channels here already

        samptim=round(stimtim.*D.fsample)+1; % time -> sample indices
        periS=floor(periT*D.fsample)+1; % epoch in samples
        epoT=periS(1)/D.fsample:1/D.fsample:(periS(2))/D.fsample; % sampled (secs) time-axis for epochs (needed only later for plotting)

        epos=zeros(size(dat,1),length(periS(1):periS(2)),length(stimdef)); % allocate zeros for speed
        for i=1:length(stimdef)
            actS=[samptim(i)+periS(1):samptim(i)+periS(2)]; %current epoch index 
            epos(:,:,i)=dat(:,actS); % epoch
        end

        disp('removing epochs with artefacts');
        goodind=find(squeeze(max(max(abs(epos))))<afxthr);
        stimdef=stimdef(goodind,:);
        epos=epos(:,:,goodind);

        %% pca in matlab
        if pcaredu
            epocat=reshape(epos,[size(epos,1) size(epos,2)*size(epos,3)]);
            [coeff,score,latent,tsquared,explained,mu] = pca(epocat');
            ncomps=min(find(cumsum(explained)>99))
            pcadat=score(:,1:ncomps); 
            epos=reshape(pcadat',[ncomps size(epos,2) size(epos,3)]);
        end

        if ~isempty(BL) 
            disp(' - baseline-correction (epochs) -');
            BLind=find(epoT>=BL(1) & epoT<=BL(2));
            if isempty(BLind)
                error('Baseline not within epoch');
            end
            BLdat=mean(epos(:,BLind,:),2);
            epos=bsxfun(@minus,epos,BLdat);
        end

        if ~isempty(smooth)
            disp('smoothing...')
            g = gausswin(smooth); % <-- this value determines the width of the smoothing window
            g = g/sum(g);
            for i=1:size(epos,1)
                for j=1:size(epos,3)
                    epos(i,:,j) = conv(epos(i,:,j), g, 'same');
                end
            end
        end

        %% RDM_COMPUTECONDITIONCOEFFS
        warning('off','stats:regress:RankDefDesignMat');
        behavVect=(stimdef(:,3)-1).*6+stimdef(:,4);
        results = rdm_computeConditionCoeffs(epos,behavVect); 

        rdmSet = rdm_computeMahalRDMset(results.betas,results.resids);
        RDM=permute(rdmSet,[3 2 1]);
   
        if savefiles
            savename=[savepath modlabs{selmod} savelab subjects{sub}];
            Dset.conds={'r1';'r2';'r3';'r4';'r5';'r6';'g1';'g2';'g3';'g4';'g5';'g6'};
            Dset.fsample=D.fsample;
            Dset.sub=subjects{sub};
            Dset.epoT=epoT;
            save(savename,'RDM','Dset');
        end
        
    end
end

    
