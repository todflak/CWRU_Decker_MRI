%  The goal of this function is to produce segmentation maps for grey
%  matter, white matter, CSF.
%  The strategy is to use SPM segmentation to warp the standard
%  TPMs (tissue probability maps) to match the structural image.
%  Tod Flak 28 Aug 2017
%
% This was then further modified to support TPM computation unlrelated to
% ASL processing.  TF 15 Aug 2018

function Compute_TPMs(AnatomicalImageFilename, LogFilename)
    global fidLog;
    OpenedLogFile = false;
    if exist('LogFilename','var') && (~isempty(LogFilename))
      fidLog = fopen(LogFilename, 'a');  %open for append
      OpenedLogFile = true;
    end

    if (exist('fidLog','var')==0) || isempty(fidLog)
      fidLog=1;  %default to standard out
    end
   
    fprintf(fidLog,'%s: Compute_TPMs, starting processing.\n', datestr(datetime('now')));
    fprintf(fidLog,'AnatomicalImageFilename:%s.\n', AnatomicalImageFilename);

    fprintf(fidLog,'\n%s: Normalize to TPM tissue segmentation model.\n', datestr(datetime('now')));


    clear matlabbatch;

    nrun = 1; % enter the number of runs here
    [CodePath,nam,ext,num] = spm_fileparts(mfilename('fullpath')); %#ok<ASGLU>
    jobfile = {[CodePath '\TPM_SimpleSegmentation_segmentjob.m']};
    jobs = repmat(jobfile, 1, nrun);
    inputs = cell(7, nrun);
    for crun = 1:nrun
        inputs{1, crun} = {AnatomicalImageFilename}; % Segment: Volumes
        TPM_Filename = [spm('Dir') '\tpm\TPM.nii'];
        inputs{2, crun} = {[TPM_Filename ',1']}; % Segment: Tissue probability map part 1 - Grey matter
        inputs{3, crun} = {[TPM_Filename ',2']}; % Segment: Tissue probability map part 2 - White matter
        inputs{4, crun} = {[TPM_Filename ',3']}; % Segment: Tissue probability map part 3 - CSF
        inputs{5, crun} = {[TPM_Filename ',4']}; % Segment: Tissue probability map part 4 - Bone
        inputs{6, crun} = {[TPM_Filename ',5']}; % Segment: Tissue probability map part 5 - Soft tissue
        inputs{7, crun} = {[TPM_Filename ',6']}; % Segment: Tissue probability map part 6 - background space
    end
    spm('defaults', 'FMRI');
    spm_jobman('run', jobs, inputs{:});

    fprintf(fidLog,'%s: For file ''%s'', completed segmentation, produced the class images for tissues 1-6:\n',  ...
       datestr(datetime('now')), AnatomicalImageFilename);
    [pth,nam,ext,~] = spm_fileparts(AnatomicalImageFilename);
    for tpm_index=1:6
        tissuename = '';
        switch tpm_index
           case 1
              tissuename = 'Grey matter';
           case 2
              tissuename = 'White matter';
           case 3
              tissuename = 'CSF';
           case 4
              tissuename = 'Bone';
           case 5
              tissuename = 'Soft tissue';
           case 6
              tissuename = 'background';
        end       
        fprintf(fidLog,'  Tissue index %i, ''%s'', file: %s\n',  ...
           tpm_index, tissuename, fullfile(pth,['c' sprintf('%i',tpm_index) nam ext]) );        
        
    end

    fprintf(fidLog,'%s: Compute_TPMs, completed processing.\n', datestr(datetime('now')));
    if (fidLog>1 && OpenedLogFile) , fclose(fidLog); end
    clear matlabbatch 

end